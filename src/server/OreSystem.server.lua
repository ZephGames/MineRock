-- ServerScriptService/OreSystem.server.lua

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local MarketplaceService = game:GetService("MarketplaceService")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Shared configs/modules
local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local OreConfig = require(Shared:WaitForChild("OreConfig"))
local PickaxeConfig = require(Shared:WaitForChild("PickaxeConfig"))
local PickaxeVisuals = require(Shared:WaitForChild("PickaxeVisuals"))
local RarityFX = require(Shared:WaitForChild("RarityFX"))

-- ====== BOOTSTRAP (prevents infinite-yield if something is missing) ======

local function ensureFolder(parent, name)
	local f = parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = parent
		warn("[BOOT] Created missing folder:", parent:GetFullName() .. "." .. name)
	end
	return f
end

local function ensureRemoteEvent(parent, name)
	local r = parent:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = parent
		warn("[BOOT] Created missing RemoteEvent:", name)
	end
	return r
end

-- Remotes (this also unblocks your client UI scripts that WaitForChild("Remotes"))
local Remotes = ensureFolder(ReplicatedStorage, "Remotes")
local MineRockEvent = ensureRemoteEvent(Remotes, "MineRock")
local InventoryUpdateEvent = ensureRemoteEvent(Remotes, "InventoryUpdate")
local SellAllEvent = ensureRemoteEvent(Remotes, "SellAll")
local TeleportToShopEvent = ensureRemoteEvent(Remotes, "TeleportToShop")
local RequestPickaxeUpgradeEvent = ensureRemoteEvent(Remotes, "RequestPickaxeUpgrade")
ensureRemoteEvent(Remotes, "DevFlyToggle") -- used by DevFly scripts

-- World / assets (these were previously hard-blocking with WaitForChild)
local OreTemplates = ensureFolder(ReplicatedStorage, "RockTemplates")
local spawnFolder = ensureFolder(Workspace, "OreSpawnPoints")

local ShopCenter = Workspace:FindFirstChild("ShopCenter")
if not ShopCenter then
	ShopCenter = Instance.new("Part")
	ShopCenter.Name = "ShopCenter"
	ShopCenter.Anchored = true
	ShopCenter.CanCollide = false
	ShopCenter.Transparency = 1
	ShopCenter.Size = Vector3.new(4, 1, 4)
	ShopCenter.Position = Vector3.new(0, 5, 0)
	ShopCenter.Parent = Workspace
	warn("[BOOT] Created placeholder ShopCenter at (0,5,0). Move it to your shop.")
end


-- =========================
-- Settings / constants
-- =========================
local PICKAXE_TOOL_NAME = "Pickaxe"
local TOOLS_FOLDER_NAME = "Tools"

local MINING_DISTANCE = 12
local SWING_COOLDOWN = 0.12
local HIT_DEBOUNCE = 0.05

local RESPAWN_TIME_DEFAULT = 6

-- If you’re using a gamepass for something later, keep as-is:
local SELL_ANYWHERE_PASS_ID = PickaxeConfig.SELL_ANYWHERE_PASS_ID or 0

-- =========================
-- State
-- =========================
local playerData = {} -- [player] = { inventory = { [oreName]=count }, coins, pickaxeId, lastSwing, ... }
local activeRocks = {} -- [rockModel] = { oreName, health, maxHealth, respawnTime, spawnCFrame, spawnPoint }

-- =========================
-- Helpers
-- =========================
local function safeGetLeaderstatsValue(player, statName)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then return nil end
	local v = ls:FindFirstChild(statName)
	return v
end

local function getCoins(player)
	local v = safeGetLeaderstatsValue(player, "Coins")
	if v then return v.Value end
	local d = playerData[player]
	return d and d.coins or 0
end

local function addCoins(player, amount)
	local v = safeGetLeaderstatsValue(player, "Coins")
	if v then
		v.Value += amount
	else
		playerData[player].coins = (playerData[player].coins or 0) + amount
	end
end

local function getPickaxeId(player)
	local d = playerData[player]
	return d and d.pickaxeId or (PickaxeConfig.DEFAULT_PICKAXE_ID or "Basic")
end

local function setPickaxeId(player, pickaxeId)
	local d = playerData[player]
	if not d then return end
	d.pickaxeId = pickaxeId

	local v = safeGetLeaderstatsValue(player, "Pickaxe")
	if v then v.Value = tostring(pickaxeId) end
end

local function getInventory(player)
	local d = playerData[player]
	if not d then return {} end
	d.inventory = d.inventory or {}
	return d.inventory
end

local function fireInventoryUpdate(player)
	local inv = getInventory(player)
	local payload = {
		inventory = inv,
		coins = getCoins(player),
		pickaxeId = getPickaxeId(player),
	}
	InventoryUpdateEvent:FireClient(player, payload)
end

local function isAliveCharacter(player)
	local char = player.Character
	if not char then return false end
	local hum = char:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function getRoot(player)
	local char = player.Character
	if not char then return nil end
	return char:FindFirstChild("HumanoidRootPart")
end

-- =========================
-- Pickaxe tool management
-- =========================
local function getToolsFolder()
	return ReplicatedStorage:FindFirstChild(TOOLS_FOLDER_NAME)
end

local function getPickaxeTemplate()
	local tools = getToolsFolder()
	if not tools then return nil end
	return tools:FindFirstChild(PICKAXE_TOOL_NAME)
end

local function ensurePickaxeEquipped(player)
	-- Tool should be in Backpack or Character
	if not player or not player.Parent then return end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		player:WaitForChild("Backpack", 5)
		backpack = player:FindFirstChildOfClass("Backpack")
	end
	if not backpack then return end

	local char = player.Character
	if not char then return end

	-- Already present?
	if backpack:FindFirstChild(PICKAXE_TOOL_NAME) or char:FindFirstChild(PICKAXE_TOOL_NAME) then
		return
	end

	-- Clone from ReplicatedStorage.Tools.Pickaxe
	local template = getPickaxeTemplate()
	if not template then
		warn("[OreSystem] No pickaxe template found at ReplicatedStorage." .. TOOLS_FOLDER_NAME .. "." .. PICKAXE_TOOL_NAME)
		return
	end

	local tool = template:Clone()
	tool.Name = PICKAXE_TOOL_NAME
	tool.Parent = backpack

	-- Apply visuals based on current pickaxe id (if your visuals module supports tool updates)
	local pickaxeId = getPickaxeId(player)
	pcall(function()
		PickaxeVisuals.ApplyToTool(tool, pickaxeId)
	end)
end

local function refreshEquippedPickaxeVisual(player)
	local pickaxeId = getPickaxeId(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	local char = player.Character
	if not backpack and not char then return end

	local tool = (backpack and backpack:FindFirstChild(PICKAXE_TOOL_NAME)) or (char and char:FindFirstChild(PICKAXE_TOOL_NAME))
	if not tool then return end

	pcall(function()
		PickaxeVisuals.ApplyToTool(tool, pickaxeId)
	end)
end

-- =========================
-- Rock spawning / setup
-- =========================
local function getSpawnPoints()
	local folder = spawnFolder
	local points = {}
	for _, inst in ipairs(folder:GetChildren()) do
		if inst:IsA("BasePart") then
			table.insert(points, inst)
		end
	end
	return points
end

local function getRockTemplateForOre(oreName)
	-- Try config-driven mapping first
	local cfg = OreConfig[oreName]
	if cfg and cfg.TemplateName then
		local t = OreTemplates:FindFirstChild(cfg.TemplateName)
		if t then return t end
	end

	-- Fallback: template with same name
	local t = OreTemplates:FindFirstChild(oreName)
	if t then return t end

	-- Fallback: "RockTemplate"
	return OreTemplates:FindFirstChild("RockTemplate")
end

local function setRockPrimaryPart(model)
	if model.PrimaryPart then return end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			model.PrimaryPart = d
			return
		end
	end
end

local function tagRock(model, oreName)
	CollectionService:AddTag(model, "MineableRock")
	model:SetAttribute("OreName", oreName)
end

local function setRockCollision(model, canCollide)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = canCollide
			d.CanQuery = true
			d.CanTouch = true
		end
	end
end

local function hideRock(model)
	model:SetAttribute("Active", false)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
		local p = d:FindFirstChildWhichIsA("ParticleEmitter", true)
		if p then p.Enabled = false end
	end
end

local function showRock(model)
	model:SetAttribute("Active", true)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 0
			d.CanCollide = true
			d.CanTouch = true
			d.CanQuery = true
		end
		local p = d:FindFirstChildWhichIsA("ParticleEmitter", true)
		if p then p.Enabled = true end
	end
end

local function spawnRockAtPoint(spawnPoint, oreName)
	local template = getRockTemplateForOre(oreName)
	if not template then
		warn("[OreSystem] Missing rock template for ore:", oreName, "in ReplicatedStorage.RockTemplates")
		return nil
	end

	local rock = template:Clone()
	rock.Name = oreName .. "_Rock"
	rock.Parent = Workspace

	if rock:IsA("Model") then
		setRockPrimaryPart(rock)
		if rock.PrimaryPart then
			rock:PivotTo(spawnPoint.CFrame)
		end
	else
		-- If someone used a single part instead of model
		if rock:IsA("BasePart") then
			rock.CFrame = spawnPoint.CFrame
		end
	end

	tagRock(rock, oreName)
	rock:SetAttribute("Active", true)

	local cfg = OreConfig[oreName] or {}
	local maxHealth = cfg.Health or 10
	local respawnTime = cfg.RespawnTime or RESPAWN_TIME_DEFAULT

	activeRocks[rock] = {
		oreName = oreName,
		health = maxHealth,
		maxHealth = maxHealth,
		respawnTime = respawnTime,
		spawnCFrame = spawnPoint.CFrame,
		spawnPoint = spawnPoint,
	}

	-- optional effects
	pcall(function()
		RarityFX.ApplyRockFX(rock, oreName)
	end)

	return rock
end

local function chooseOreForPoint(_spawnPoint)
	-- If your OreConfig has a weighted list, keep it simple:
	if OreConfig.GetRandomOre then
		return OreConfig.GetRandomOre()
	end

	-- Fallback: pick first ore in config table
	for oreName, _ in pairs(OreConfig) do
		if type(oreName) == "string" and type(_) == "table" then
			return oreName
		end
	end

	return "Stone"
end

local function initialSpawnAll()
	local points = getSpawnPoints()
	if #points == 0 then
		warn("[OreSystem] No OreSpawnPoints found. Put Parts under Workspace.OreSpawnPoints.")
	end

	for _, sp in ipairs(points) do
		local oreName = chooseOreForPoint(sp)
		spawnRockAtPoint(sp, oreName)
	end
end

-- =========================
-- Mining logic
-- =========================
local function canPlayerMineRock(player, rock)
	if not isAliveCharacter(player) then
		return false, "dead"
	end

	local root = getRoot(player)
	if not root then
		return false, "no_root"
	end

	if not rock or not rock.Parent then
		return false, "no_rock"
	end

	if rock:GetAttribute("Active") == false then
		return false, "inactive"
	end

	local rockPos
	if rock:IsA("Model") then
		if rock.PrimaryPart then
			rockPos = rock.PrimaryPart.Position
		else
			local pp = rock:FindFirstChildWhichIsA("BasePart", true)
			if pp then rockPos = pp.Position end
		end
	elseif rock:IsA("BasePart") then
		rockPos = rock.Position
	end

	if not rockPos then
		return false, "no_pos"
	end

	local dist = (root.Position - rockPos).Magnitude
	if dist > MINING_DISTANCE then
		return false, "too_far"
	end

	return true
end

local function awardOreToPlayer(player, oreName, amount)
	local inv = getInventory(player)
	inv[oreName] = (inv[oreName] or 0) + (amount or 1)
	fireInventoryUpdate(player)
end

local function damageRock(player, rock, damage)
	local state = activeRocks[rock]
	if not state then return end

	state.health -= damage
	if state.health > 0 then
		return
	end

	-- Rock "breaks"
	state.health = 0
	hideRock(rock)

	-- Award drop(s)
	local oreName = state.oreName
	local cfg = OreConfig[oreName] or {}
	local dropAmount = cfg.DropAmount or 1
	awardOreToPlayer(player, oreName, dropAmount)

	-- Respawn
	task.delay(state.respawnTime, function()
		if not rock or not rock.Parent then return end
		-- Reset
		state.health = state.maxHealth
		-- Optionally reroll ore type:
		local newOre = chooseOreForPoint(state.spawnPoint)
		state.oreName = newOre
		local newCfg = OreConfig[newOre] or {}
		state.maxHealth = newCfg.Health or state.maxHealth
		state.health = state.maxHealth
		state.respawnTime = newCfg.RespawnTime or state.respawnTime
		rock:SetAttribute("OreName", newOre)

		-- Re-apply FX
		pcall(function()
			RarityFX.ApplyRockFX(rock, newOre)
		end)

		showRock(rock)
	end)
end

-- =========================
-- Remotes
-- =========================
local lastHit = {} -- [player] = tick()

MineRockEvent.OnServerEvent:Connect(function(player, rock)
	if not playerData[player] then return end

	local now = os.clock()
	if lastHit[player] and (now - lastHit[player]) < HIT_DEBOUNCE then
		return
	end
	lastHit[player] = now

	local ok, reason = canPlayerMineRock(player, rock)
	if not ok then
		return
	end

	-- pickaxe power from config
	local pickaxeId = getPickaxeId(player)
	local pCfg = PickaxeConfig.GetPickaxe and PickaxeConfig.GetPickaxe(pickaxeId) or (PickaxeConfig[pickaxeId] or {})
	local power = pCfg.Power or 1

	damageRock(player, rock, power)
end)

SellAllEvent.OnServerEvent:Connect(function(player)
	if not playerData[player] then return end

	local inv = getInventory(player)
	local total = 0

	for oreName, count in pairs(inv) do
		local cfg = OreConfig[oreName] or {}
		local value = cfg.Value or 1
		total += (count * value)
		inv[oreName] = 0
	end

	addCoins(player, total)
	fireInventoryUpdate(player)
end)

TeleportToShopEvent.OnServerEvent:Connect(function(player)
	if not isAliveCharacter(player) then return end
	local root = getRoot(player)
	if not root then return end
	root.CFrame = ShopCenter.CFrame + Vector3.new(0, 5, 0)
end)

RequestPickaxeUpgradeEvent.OnServerEvent:Connect(function(player, nextPickaxeId)
	if not playerData[player] then return end

	local currentId = getPickaxeId(player)
	if currentId == nextPickaxeId then
		return
	end

	-- validate upgrade path (if your config supports it)
	local ok = true
	if PickaxeConfig.CanUpgradeTo then
		ok = PickaxeConfig.CanUpgradeTo(currentId, nextPickaxeId)
	end
	if not ok then
		return
	end

	-- cost
	local cost = 0
	if PickaxeConfig.GetPickaxeCost then
		cost = PickaxeConfig.GetPickaxeCost(nextPickaxeId) or 0
	else
		local nextCfg = PickaxeConfig[nextPickaxeId] or {}
		cost = nextCfg.Cost or 0
	end

	if getCoins(player) < cost then
		return
	end

	addCoins(player, -cost)
	setPickaxeId(player, nextPickaxeId)

	-- update visuals immediately if they already have the tool
	refreshEquippedPickaxeVisual(player)

	fireInventoryUpdate(player)
end)

-- =========================
-- Player lifecycle
-- =========================
local function setupPlayer(player)
	playerData[player] = playerData[player] or {
		inventory = {},
		coins = 0,
		pickaxeId = PickaxeConfig.DEFAULT_PICKAXE_ID or "Basic",
	}

	-- If leaderstats exist, sync from them
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local pickaxeStat = ls:FindFirstChild("Pickaxe")
		if pickaxeStat then
			playerData[player].pickaxeId = pickaxeStat.Value
		end
	end

	-- Give pickaxe on join
	task.defer(function()
		ensurePickaxeEquipped(player)
		fireInventoryUpdate(player)
	end)

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		ensurePickaxeEquipped(player)
		refreshEquippedPickaxeVisual(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	playerData[player] = nil
	lastHit[player] = nil
end)

-- =========================
-- Startup
-- =========================
task.defer(function()
	initialSpawnAll()
end)
