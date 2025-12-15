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
local STREAK_WINDOW   = 4
local STREAK_DAMAGE_STEP = 0.03
local STREAK_YIELD_STEP = 0.015
local STREAK_DAMAGE_CAP = 0.35
local STREAK_YIELD_CAP = 0.25
local BURST_BASE_CHANCE = 0.18

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
local streakState = {}

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
        local critChance = cfg.CritChance or 0
        local critMultiplier = cfg.CritMultiplier or 1.5
        return damage, cooldown, tierIndex, cfg, critChance, critMultiplier
end

local function updateStreak(player, now)
        local data = streakState[player]
        if not data then
                data = { count = 0, lastHit = 0, damageBonus = 0, yieldBonus = 0 }
        end

        if now - (data.lastHit or 0) <= STREAK_WINDOW then
                data.count += 1
        else
                data.count = 1
        end

        data.lastHit = now
        data.damageBonus = math.min(STREAK_DAMAGE_CAP, (data.count - 1) * STREAK_DAMAGE_STEP)
        data.yieldBonus = math.min(STREAK_YIELD_CAP, (data.count - 1) * STREAK_YIELD_STEP)

        streakState[player] = data

        player:SetAttribute("MiningStreak", data.count)
        player:SetAttribute("MiningMomentum", 1 + data.damageBonus)

        return data
end

local function resetStreak(player)
        streakState[player] = nil
        player:SetAttribute("MiningStreak", 0)
        player:SetAttribute("MiningMomentum", 1)
end

local function applyCritical(damage, critChance, critMultiplier)
        if critChance <= 0 then
                return damage, false
        end

        if math.random() < critChance then
                return damage * critMultiplier, true
        end

        return damage, false
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

local function isValidSurface(result)
        if not result then
                return false
        end

        if result.Material == Enum.Material.Water then
                return false
        end

        local inst = result.Instance
        if inst:IsA("Terrain") then
                return true
        end

        if inst:IsA("BasePart") then
                if not inst.CanCollide then
                        return false
                end

                if not inst.Anchored then
                        return false
                end

                return true
        end

        return false
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.FilterDescendantsInstances = { rockFolder }
rayParams.IgnoreWater = true

local function findGroundPosition(spawnPoint)
	for _ = 1, 10 do
		local angle = math.random() * math.pi * 2
		local radius = math.random() * SPAWN_RADIUS
                local offset = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)

                local origin = spawnPoint.Position + offset + Vector3.new(0, 40, 0)
                local result = Workspace:Raycast(origin, Vector3.new(0, -100, 0), rayParams)

                if isValidSurface(result) then
                        local pos = result.Position
                        if canPlaceAt(pos) then
                                return pos, result.Normal
                        end
                end
        end
        return nil
end

local function buildSurfaceCFrame(position, normal)
        local up = normal.Unit

        local fallback = math.abs(up:Dot(Vector3.new(0, 1, 0))) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
        local right = up:Cross(fallback)
        if right.Magnitude < 1e-4 then
                right = up:Cross(Vector3.new(0, 0, 1))
        end
        right = right.Unit

        local baseCFrame = CFrame.fromMatrix(position, right, up)
        local twist = CFrame.fromAxisAngle(up, math.random() * math.pi * 2)

        return baseCFrame * twist
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

        local pos, normal = findGroundPosition(spawnPoint)
        if not pos or not normal then
                rock:Destroy()
                return nil
        end

        rock:SetPrimaryPartCFrame(buildSurfaceCFrame(pos, normal))

	-- random size
	local sizeMult = math.random(math.floor(SCALE_MIN * 100), math.floor(SCALE_MAX * 100)) / 100
	rock:SetAttribute("SizeMultiplier", sizeMult)
	rock:SetAttribute("InitialScale", sizeMult)
	rock:ScaleTo(sizeMult)

	-- size-based health
	local baseMaxHealth = config.MaxHealth or 100
	local sizeHealthMult = sizeMult ^ 1.2
	local scaledMaxHealth = math.max(10, math.floor(baseMaxHealth * sizeHealthMult + 0.5))

        rock:SetAttribute("BaseMaxHealth", baseMaxHealth)
        rock:SetAttribute("MaxHealth", scaledMaxHealth)
        rock:SetAttribute("Health", scaledMaxHealth)
        rock:SetAttribute("OreType", oreType)
        rock:SetAttribute("Depleted", false)
        rock:SetAttribute("HitCount", 0)

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

local function rollBurstChance(streakCount)
        return math.min(0.85, BURST_BASE_CHANCE + math.max(0, streakCount - 1) * 0.02)
end

local function calculateDropAmount(config, sizeMult, streak, isCrit)
        local baseYield = (config and config.Yield) or 1
        local rawDrop = baseYield * sizeMult

        local streakBonus = rawDrop * ((streak and streak.yieldBonus) or 0)
        local critBonus = isCrit and (rawDrop * 0.15) or 0

        local burst = 0
        local burstRange = config and config.BurstYield
        if burstRange and math.random() < rollBurstChance((streak and streak.count) or 1) then
                local minExtra = burstRange[1] or burstRange.min or 1
                local maxExtra = burstRange[2] or burstRange.max or minExtra
                burst = math.random(minExtra, maxExtra)
        end

        local total = math.max(1, math.floor(rawDrop + streakBonus + critBonus + burst + 0.5))
        return total, burst > 0
end

local function awardTreasure(player, oreType, config, streakCount)
        local treasureChance = (config and config.TreasureChance) or 0
        treasureChance += math.min(0.08, math.max(0, streakCount - 1) * 0.005)

        if math.random() < treasureChance then
                local coins = getOrCreateCoins(player)
                local coinReward = math.floor(((config and config.Value) or 1) * math.random(2, 5))
                coins.Value += coinReward
                UpdateQuestSafe(player, "EarnCoins", coinReward)

                local shards = 0
                if math.random() < 0.35 then
                        shards = 1 + math.floor(math.max(0, streakCount - 1) / 7)
                        addOreToInventory(player, "GemShards", shards)
                end

                return coinReward, shards
        end

        return 0, 0
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

        local damage, cooldown, _, _, critChance, critMultiplier = getPickaxeStats(player)
        local streak = updateStreak(player, now)

        local cooldownScale = math.max(0.55, 1 - streak.damageBonus * 0.35)
        local last = lastHitTimes[player]
        if last and (now - last) < cooldown * cooldownScale then
                return
        end
        lastHitTimes[player] = now

        local maxHealth = rock:GetAttribute("MaxHealth")
        local health = rock:GetAttribute("Health")
        if not maxHealth or not health then return end

        local scaledDamage = damage * (1 + streak.damageBonus)
        local finalDamage, isCrit = applyCritical(scaledDamage, critChance, critMultiplier)

        health -= finalDamage
        rock:SetAttribute("Health", health)

        local hitCount = (rock:GetAttribute("HitCount") or 0) + 1
        rock:SetAttribute("HitCount", hitCount)

        if health > 0 then
                if hitCount % 2 == 0 then
                        updateRockScale(rock)
                end
                updateOreLabel(rock)
                return
        end

        rock:SetAttribute("Health", 0)
        rock:SetAttribute("Depleted", true)

        local oreType = rock:GetAttribute("OreType") or "Stone"
        local config = OreConfig[oreType]
        local respawnTime = (config and config.RespawnTime) or 10

        local sizeMult = rock:GetAttribute("SizeMultiplier") or 1

        local dropAmount = calculateDropAmount(config, sizeMult, streak, isCrit)

        addOreToInventory(player, oreType, dropAmount)

        addTotalMined(player, 1)
        UpdateQuestSafe(player, "MineCount", 1)
        UpdateQuestSafe(player, "MineSpecific", 1, oreType)

        local _, shards = awardTreasure(player, oreType, config, streak.count)
        if shards > 0 then
                player:SetAttribute("RecentShardGain", shards)
        end

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

MineRockEvent.OnServerEvent:Connect(onMineRock)

-- ====== player setup ======

Players.PlayerAdded:Connect(function(player)
        getOrCreateCoins(player)

        player:SetAttribute("MiningStreak", 0)
        player:SetAttribute("MiningMomentum", 1)
        player:SetAttribute("RecentShardGain", 0)

        local tierValue = Instance.new("IntValue")
        tierValue.Name = "PickaxeTier"
        tierValue.Value = 1
        tierValue.Parent = player

        getOrCreateInventory(player)
end)

Players.PlayerRemoving:Connect(function(player)
        lastHitTimes[player] = nil
        lastMineRemoteTimes[player] = nil
        resetStreak(player)
end)

-- ====== initial rock spawn ======

for _, spawnPoint in ipairs(spawnFolder:GetChildren()) do
	if spawnPoint:IsA("BasePart") then
		for _ = 1, ROCKS_PER_POINT do
			spawnOreAtPoint(spawnPoint)
		end
	end
end
