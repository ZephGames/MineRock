-- ServerScriptService.OreSystem

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local OreConfig = require(Shared:WaitForChild("OreConfig"))
local PickaxeConfig = require(Shared:WaitForChild("PickaxeConfig"))
local RarityFX = require(Shared:WaitForChild("RarityFX"))

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local MineRockEvent = Remotes:WaitForChild("MineRock")
local InventoryUpdateEvent = Remotes:WaitForChild("InventoryUpdate")
local SellAllEvent = Remotes:WaitForChild("SellAll")
local TeleportToShopEvent = Remotes:WaitForChild("TeleportToShop")
local RequestPickaxeUpgradeEvent = Remotes:WaitForChild("RequestPickaxeUpgrade")

local OreTemplates = ReplicatedStorage:WaitForChild("RockTemplates")
local spawnFolder = Workspace:WaitForChild("OreSpawnPoints")
local ShopCenter = Workspace:WaitForChild("ShopCenter")

local rockFolder = Workspace:FindFirstChild("Rocks")
if not rockFolder then
	rockFolder = Instance.new("Folder")
	rockFolder.Name = "Rocks"
	rockFolder.Parent = Workspace
end

local rarityColors = OreConfig.RarityColors or {}

-- ====== tuning constants ======
local HIT_RANGE       = 15
local SPAWN_RADIUS    = 100
local ROCKS_PER_POINT = 20
local MIN_ROCK_GAP    = 20
local SCALE_MIN       = 0.7
local SCALE_MAX       = 2.5
local SELL_RADIUS     = 15

-- ====== gamepass (placeholder) ======
local SELL_ANYWHERE_PASS_ID = 1631522468
local gamepassCache = {}

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if passId == SELL_ANYWHERE_PASS_ID and purchased then
		gamepassCache[player.UserId] = true
	end
end)

local function ownsSellAnywherePass(player)
	if player:GetAttribute("ForceSellAnywhere") == true then
		return true
	end

	if gamepassCache[player.UserId] ~= nil then
		return gamepassCache[player.UserId]
	end

	local ok, result = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, SELL_ANYWHERE_PASS_ID)
	end)

	if ok then
		gamepassCache[player.UserId] = result
		return result
	else
		warn("Gamepass check failed:", result)
		return false
	end
end

Players.PlayerRemoving:Connect(function(player)
	gamepassCache[player.UserId] = nil
end)

local function UpdateQuestSafe(player, questType, amount, oreType)
	local fn = _G.UpdateQuest
	if typeof(fn) == "function" then
		fn(player, questType, amount, oreType)
	end
end

local function addTotalMined(player, amount)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then return end
	local totalMined = ls:FindFirstChild("TotalMined")
	if totalMined then
		totalMined.Value += (amount or 1)
	end
end

-- ====== inventory & coins ======

local function getOrCreateInventory(player)
	local inv = player:FindFirstChild("Inventory")
	if not inv then
		inv = Instance.new("Folder")
		inv.Name = "Inventory"
		inv.Parent = player
	end
	return inv
end

local function addOreToInventory(player, oreType, amount)
	if amount == 0 then return end

	local inv = getOrCreateInventory(player)
	local item = inv:FindFirstChild(oreType)
	if not item then
		item = Instance.new("IntValue")
		item.Name = oreType
		item.Value = 0
		item.Parent = inv
	end

	item.Value += amount
	if item.Value < 0 then
		item.Value = 0
	end

	InventoryUpdateEvent:FireClient(player, oreType, item.Value)
end

local function getOrCreateLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	return ls
end

local function getOrCreateCoins(player)
	local ls = getOrCreateLeaderstats(player)
	local coins = ls:FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = ls
	end
	return coins
end

-- ====== pickaxe helpers ======

local lastHitTimes = {}
local lastMineRemoteTimes = {}
local REMOTE_MIN_INTERVAL = 0.05

local function getPickaxeTierValue(player)
	local v = player:FindFirstChild("PickaxeTier")
	if v and typeof(v.Value) == "number" then
		local maxTier = PickaxeConfig.GetTierCount()
		return math.clamp(v.Value, 1, maxTier)
	end
	return 1
end

local function getPickaxeStats(player)
	local tierIndex = getPickaxeTierValue(player)
	local cfg = PickaxeConfig.GetTier(tierIndex) or {}
	local damage = cfg.Damage or 10
	local cooldown = cfg.Cooldown or 0.5
	return damage, cooldown, tierIndex, cfg
end

local function handlePickaxeUpgradeRequest(player, targetTierIndex)
	if typeof(targetTierIndex) ~= "number" then return end

	local tiers = PickaxeConfig.Tiers
	local maxTier = #tiers
	if targetTierIndex < 1 or targetTierIndex > maxTier then
		return
	end

	local pickaxeValue = player:FindFirstChild("PickaxeTier")
	if not pickaxeValue then
		warn("No PickaxeTier value for", player.Name)
		return
	end

	local currentTier = getPickaxeTierValue(player)

	if targetTierIndex <= currentTier then
		return
	end

	if targetTierIndex > currentTier + 1 then
		warn(("Player %s tried to skip tiers (%d -> %d)"):format(player.Name, currentTier, targetTierIndex))
		return
	end

	local targetConfig = tiers[targetTierIndex]
	if not targetConfig then
		warn("No config for tier index", targetTierIndex)
		return
	end

	local coins = getOrCreateCoins(player)
	local cost = targetConfig.Cost or 0

	if coins.Value < cost then
		warn(("Player %s doesn't have enough coins: %d / %d"):format(player.Name, coins.Value, cost))
		return
	end

	coins.Value -= cost
	pickaxeValue.Value = targetTierIndex

	print(("Upgraded %s to %s pickaxe (tier %d)"):format(
		player.Name,
		targetConfig.DisplayName or ("Tier "..targetTierIndex),
		targetTierIndex
	))
end

RequestPickaxeUpgradeEvent.OnServerEvent:Connect(handlePickaxeUpgradeRequest)

-- ====== shop helpers ======

local function isPlayerNearShop(player)
	if not ShopCenter then return false end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return false end

	local centerPos
	if ShopCenter:IsA("BasePart") then
		centerPos = ShopCenter.Position
	elseif ShopCenter:IsA("Model") and ShopCenter.PrimaryPart then
		centerPos = ShopCenter.PrimaryPart.Position
	end
	if not centerPos then return false end

	local distance = (hrp.Position - centerPos).Magnitude
	return distance <= SELL_RADIUS
end

local function sellAllOres(player)
	if not ownsSellAnywherePass(player) and not isPlayerNearShop(player) then
		return
	end

	local inv = player:FindFirstChild("Inventory")
	if not inv then return end

	local totalCoins = 0

	for oreName, config in pairs(OreConfig) do
		if type(config) == "table" and oreName ~= "SpawnWeights" and oreName ~= "RarityColors" then
			local item = inv:FindFirstChild(oreName)
			if item and item.Value > 0 then
				local amount = item.Value
				local valuePer = config.Value or 1
				totalCoins += amount * valuePer
				addOreToInventory(player, oreName, -amount)
			end
		end
	end

	if totalCoins > 0 then
		local coins = getOrCreateCoins(player)
		coins.Value += totalCoins
		UpdateQuestSafe(player, "EarnCoins", totalCoins)
	end
end

SellAllEvent.OnServerEvent:Connect(function(player)
	sellAllOres(player)
end)

TeleportToShopEvent.OnServerEvent:Connect(function(player)
	if not ShopCenter then return end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local centerPos
	if ShopCenter:IsA("BasePart") then
		centerPos = ShopCenter.Position
	elseif ShopCenter:IsA("Model") and ShopCenter.PrimaryPart then
		centerPos = ShopCenter.PrimaryPart.Position
	end
	if not centerPos then return end

	local targetPos = centerPos + Vector3.new(0, 4, 0)
	hrp.CFrame = CFrame.new(targetPos, targetPos + hrp.CFrame.LookVector)
end)

-- ====== rock visuals ======

local function updateRockScale(rock)
	local initialScale = rock:GetAttribute("InitialScale") or 1
	local maxHealth = rock:GetAttribute("MaxHealth") or 1
	local health = rock:GetAttribute("Health") or maxHealth
	if maxHealth <= 0 then return end

	local frac = math.clamp(health / maxHealth, 0.4, 1)
        local targetScale = initialScale * frac

        if rock.PrimaryPart then
                rock:ScaleTo(targetScale)
        end
end

local function updateOreLabel(rock)
	local oreType = rock:GetAttribute("OreType") or "?"
	local config = OreConfig[oreType]
	if not config then return end

	local gui = rock:FindFirstChild("OreLabel")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "OreLabel"
		gui.Size = UDim2.new(0, 120, 0, 40)
		gui.StudsOffset = Vector3.new(0, 4, 0)
		gui.AlwaysOnTop = true
		gui.MaxDistance = 50
		gui.Adornee = rock.PrimaryPart
		gui.Parent = rock

		local text = Instance.new("TextLabel")
		text.Name = "Text"
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, 0, 1, 0)
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.TextStrokeTransparency = 0.4
		text.TextStrokeColor3 = Color3.new(0, 0, 0)
		text.Parent = gui
	end

	local textLabel = gui:FindFirstChild("Text")
	if not textLabel then return end

	local rarity = config.Rarity
	local color = rarityColors[rarity] or Color3.new(1, 1, 1)
	local displayName = config.DisplayName or oreType
	local health = rock:GetAttribute("Health") or 0
	local maxHealth = rock:GetAttribute("MaxHealth") or health

	textLabel.TextColor3 = color
	textLabel.Text = string.format("%s\n%d / %d", displayName, math.max(0, math.floor(health)), math.floor(maxHealth))
end

-- ====== spawn helpers ======

local function chooseRandomOreType()
	local weights = OreConfig.SpawnWeights or {}
	local totalWeight = 0
	for _, w in pairs(weights) do
		totalWeight += w
	end
	if totalWeight <= 0 then
		return "Stone"
	end

	local r = math.random() * totalWeight
	local cumulative = 0
	for oreName, w in pairs(weights) do
		cumulative += w
		if r <= cumulative then
			return oreName
		end
	end

	return "Stone"
end

local function canPlaceAt(position)
	for _, rock in ipairs(rockFolder:GetChildren()) do
		local primary = rock.PrimaryPart
		if primary then
			local dist = (primary.Position - position).Magnitude
			if dist < MIN_ROCK_GAP then
				return false
			end
		end
	end
	return true
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { rockFolder }

local function findGroundPosition(spawnPoint)
	for _ = 1, 10 do
		local angle = math.random() * math.pi * 2
		local radius = math.random() * SPAWN_RADIUS
		local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

		local origin = spawnPoint.Position + offset + Vector3.new(0, 40, 0)
		local result = Workspace:Raycast(origin, Vector3.new(0, -100, 0), rayParams)

		if result then
			local pos = result.Position
			if canPlaceAt(pos) then
				return pos
			end
		end
	end
	return nil
end

local function spawnOreAtPoint(spawnPoint)
	local oreType = chooseRandomOreType()
	local config = OreConfig[oreType]
	if not config then
		warn("Missing OreConfig for", oreType)
		return nil
	end

	local templateName = config.TemplateName or oreType
	local template = OreTemplates:FindFirstChild(templateName)
	if not template then
		warn("Missing ore template:", templateName)
		return nil
	end

	local rock = template:Clone()
	rock.Name = oreType .. "Rock"
	rock.Parent = rockFolder

	if not rock.PrimaryPart then
		rock.PrimaryPart = rock:FindFirstChildWhichIsA("BasePart")
	end
	if not rock.PrimaryPart then
		warn("Rock template has no PrimaryPart:", templateName)
		rock:Destroy()
		return nil
	end

	local pos = findGroundPosition(spawnPoint)
	if not pos then
		rock:Destroy()
		return nil
	end

	local yRot = math.random() * math.pi * 2
	rock:SetPrimaryPartCFrame(CFrame.new(pos) * CFrame.Angles(0, yRot, 0))

	-- random size
	local sizeMult = math.random(math.floor(SCALE_MIN * 100), math.floor(SCALE_MAX * 100)) / 100
        rock:SetAttribute("SizeMultiplier", sizeMult)
        rock:SetAttribute("InitialScale", sizeMult)
        rock:ScaleTo(sizeMult)
        rock:SetAttribute("HitsSinceScale", 0)

	-- size-based health
	local baseMaxHealth = config.MaxHealth or 100
	local sizeHealthMult = sizeMult ^ 1.2
	local scaledMaxHealth = math.max(10, math.floor(baseMaxHealth * sizeHealthMult + 0.5))

	rock:SetAttribute("BaseMaxHealth", baseMaxHealth)
	rock:SetAttribute("MaxHealth", scaledMaxHealth)
	rock:SetAttribute("Health", scaledMaxHealth)
	rock:SetAttribute("OreType", oreType)
	rock:SetAttribute("Depleted", false)

	-- store rarity on the rock + apply FX
	local rarity = (config and config.Rarity) or "Common"
	rock:SetAttribute("Rarity", rarity)
	local color = rarityColors[rarity] or Color3.new(1, 1, 1)
	RarityFX.ApplyToRock(rock, rarity, color)

	local spValue = Instance.new("ObjectValue")
	spValue.Name = "SpawnPoint"
	spValue.Value = spawnPoint
	spValue.Parent = rock

	updateRockScale(rock)
	updateOreLabel(rock)

	return rock
end

-- ====== mining ======

local function onMineRock(player, hitInstance)
	if typeof(hitInstance) ~= "Instance" then
		return
	end

	local now = os.clock()
	local lastRemote = lastMineRemoteTimes[player]
	if lastRemote and (now - lastRemote) < REMOTE_MIN_INTERVAL then
		return
	end
	lastMineRemoteTimes[player] = now

	local rock
	if hitInstance:IsA("Model") then
		rock = hitInstance
	elseif hitInstance:IsA("BasePart") and hitInstance.Parent and hitInstance.Parent:IsA("Model") then
		rock = hitInstance.Parent
	else
		return
	end

	if not rock:IsDescendantOf(rockFolder) then
		return
	end

	if rock:GetAttribute("Depleted") then
		return
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local primary = rock.PrimaryPart
	if not primary then return end

	local distance = (hrp.Position - primary.Position).Magnitude
	if distance > HIT_RANGE then
		return
	end

	local damage, cooldown = getPickaxeStats(player)
	local last = lastHitTimes[player]
	if last and (now - last) < cooldown then
		return
	end
	lastHitTimes[player] = now

        local maxHealth = rock:GetAttribute("MaxHealth")
        local health = rock:GetAttribute("Health")
        if not maxHealth or not health then return end

        health -= damage
        rock:SetAttribute("Health", health)

        local hitsSinceScale = rock:GetAttribute("HitsSinceScale") or 0
        hitsSinceScale += 1

        local shouldUpdateScale = hitsSinceScale >= 3 or health <= 0
        if shouldUpdateScale then
                rock:SetAttribute("HitsSinceScale", 0)
                updateRockScale(rock)
        else
                rock:SetAttribute("HitsSinceScale", hitsSinceScale)
        end
        updateOreLabel(rock)

	if health <= 0 then
		rock:SetAttribute("Health", 0)
		rock:SetAttribute("Depleted", true)

		local oreType = rock:GetAttribute("OreType") or "Stone"
		local config = OreConfig[oreType]
		local respawnTime = (config and config.RespawnTime) or 10

		local sizeMult = rock:GetAttribute("SizeMultiplier") or 1
		local baseYield = (config and config.Yield) or 1

		local rawDrop = baseYield * sizeMult
		local dropAmount = math.max(1, math.floor(rawDrop + 0.5))

		addOreToInventory(player, oreType, dropAmount)

		addTotalMined(player, 1)
		UpdateQuestSafe(player, "MineCount", 1)
		UpdateQuestSafe(player, "MineSpecific", 1, oreType)

		local spValue = rock:FindFirstChild("SpawnPoint")
		local spawnPoint = spValue and spValue.Value

		-- play break FX before destroy
		local rarity = rock:GetAttribute("Rarity") or ((config and config.Rarity) or "Common")
		RarityFX.PlayBreak(rock, rarity)

		rock:Destroy()

		if spawnPoint then
			task.delay(respawnTime, function()
				if spawnPoint.Parent then
					spawnOreAtPoint(spawnPoint)
				end
			end)
		end
	end
end

MineRockEvent.OnServerEvent:Connect(onMineRock)

-- ====== player setup ======

Players.PlayerAdded:Connect(function(player)
	getOrCreateCoins(player)

	local tierValue = Instance.new("IntValue")
	tierValue.Name = "PickaxeTier"
	tierValue.Value = 1
	tierValue.Parent = player

	getOrCreateInventory(player)
end)

Players.PlayerRemoving:Connect(function(player)
	lastHitTimes[player] = nil
	lastMineRemoteTimes[player] = nil
end)

-- ====== initial rock spawn ======

for _, spawnPoint in ipairs(spawnFolder:GetChildren()) do
	if spawnPoint:IsA("BasePart") then
		for _ = 1, ROCKS_PER_POINT do
			spawnOreAtPoint(spawnPoint)
		end
	end
end
