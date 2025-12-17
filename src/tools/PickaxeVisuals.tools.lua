-- LocalScript: ReplicatedStorage/Tools/Pickaxe/PickaxeVisuals
-- Swaps the 3D model + updates hotbar name whenever the player's PickaxeTier changes.
-- Listens to both a Player IntValue("PickaxeTier") and a Player Attribute("PickaxeTier").

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local PickaxeConfig = require(Shared:WaitForChild("PickaxeConfig"))

local player = Players.LocalPlayer
local tool = script.Parent

-- Where the tier models live (preferred) with a fallback
local ModelsFolder =
	ReplicatedStorage:FindFirstChild("PickaxeModels")
	or (ReplicatedStorage:FindFirstChild("Assets") and ReplicatedStorage.Assets:FindFirstChild("Pickaxes"))

-- Neutralize the tiny placeholder handle in the template Tool (so it doesn't show)
do
	local ph = tool:FindFirstChild("Handle")
	if ph and ph:IsA("BasePart") then
		ph.Transparency = 1
		ph.CanCollide = false
		ph.Massless = true
		ph.Name = "_PlaceholderHandle"
	end
end

-- State
local activeModel = nil
local handle = nil
local baseHandleSize = nil
local visualParts = {}
local light = nil

local rainbowActive = false
local rainbowHue = 0

local DEBUG = false
local function log(...) if DEBUG then print("[PickaxeVisuals]", ...) end end

-- Helpers
local function gatherParts(root)
	local t = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then table.insert(t, d) end
	end
	return t
end

local function ensureLight()
	if not handle then return end
	light = handle:FindFirstChild("PickaxeGlow")
	if not light then
		light = Instance.new("PointLight")
		light.Name = "PickaxeGlow"
		light.Range = 12
		light.Brightness = 0
		light.Enabled = false
		light.Parent = handle
	end
end

local function findOrMakeHandle(model)
	local h = model:FindFirstChild("Handle", true)
	if h and h:IsA("BasePart") then return h end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then return d end
	end
	return nil
end

local function destroyOldGeometryExcept(keep)
	for _, child in ipairs(tool:GetChildren()) do
		if child ~= keep then
			-- remove models/parts/folders that could be old geometry,
			-- keep scripts, sounds, animations, etc.
			if child:IsA("Model") or child:IsA("Folder") or child:IsA("BasePart") then
				if child.Name ~= "SwingAnimation" and child.Name ~= "SwingSound" and child.Name ~= "_PlaceholderHandle" then
					child:Destroy()
				end
			end
		end
	end
end

local function findTemplateForTier(cfg, tierIndex)
	if not ModelsFolder then return nil end
	if cfg.ModelName and ModelsFolder:FindFirstChild(cfg.ModelName) then
		return ModelsFolder[cfg.ModelName]
	end
	if cfg.Id and ModelsFolder:FindFirstChild(cfg.Id) then
		return ModelsFolder[cfg.Id]
	end
	local guess = "Pickaxe"..tostring(tierIndex) -- optional fallback name
	if ModelsFolder:FindFirstChild(guess) then
		return ModelsFolder[guess]
	end
	return nil
end

local function mountModelForTier(cfg, tierIndex)
	local template = findTemplateForTier(cfg, tierIndex)
	if not template then
		log("No model found for tier", tierIndex, cfg.Id or "?")
		return
	end

	-- clear any old geometry first
	destroyOldGeometryExcept(nil)

	-- kill previous
	if activeModel then
		activeModel:Destroy()
		activeModel = nil
	end

	-- clone + attach
	activeModel = template:Clone()
	activeModel.Parent = tool

	-- set Tool.Handle to the new handle
	handle = findOrMakeHandle(activeModel)
	if handle then
		tool.RequiresHandle = true
		tool.Handle = handle
		handle.CanCollide = false
		handle.Massless = true
		baseHandleSize = handle.Size
	else
		log("Warning: mounted model has no BasePart")
	end

	-- build parts+light
	visualParts = gatherParts(activeModel)
	ensureLight()

	-- delete placeholder if still present
	local ph = tool:FindFirstChild("_PlaceholderHandle")
	if ph then ph:Destroy() end
end

local function getTierIndex()
	-- prefer IntValue
	local v = player:FindFirstChild("PickaxeTier")
	if v and typeof(v.Value) == "number" then return v.Value end
	-- fallback attribute
	local a = player:GetAttribute("PickaxeTier")
	if typeof(a) == "number" then return a end
	return 1
end

local applying = false
local function applyTierVisuals()
	if applying then return end
	applying = true

	local rawIndex = getTierIndex()
	local maxTier = PickaxeConfig.GetTierCount()
	local index = math.clamp(rawIndex, 1, maxTier)
	local cfg = PickaxeConfig.GetTier(index) or {}

	-- name in hotbar + tooltip
	local disp = cfg.DisplayName or cfg.Id or ("Pickaxe "..index)
	tool.Name = disp
	tool.ToolTip = disp

	-- swap the model
	mountModelForTier(cfg, index)

	-- visuals
	local color = cfg.Color or Color3.new(1,1,1)
	local scale = cfg.SizeScale or 1
	local glowBright = cfg.GlowBrightness or 0
	local rainbow = cfg.RainbowGlow or false

	-- scale
	if handle and baseHandleSize then
		handle.Size = baseHandleSize * scale
	end

	-- static color/material if not rainbow
	if not rainbow then
		for _, part in ipairs(visualParts) do
			part.Material = (glowBright > 0) and Enum.Material.Neon or Enum.Material.Metal
			part.Color = color
		end
	end

	-- light
	if light then
		light.Brightness = glowBright
		light.Enabled = glowBright > 0
		if not rainbow then light.Color = color end
	end

	rainbowActive = rainbow
	if not rainbow then rainbowHue = 0 end

	log(("Applied tier %d (%s)"):format(index, tostring(cfg.Id)))
	applying = false
end

-- RGB animation
RunService.Heartbeat:Connect(function(dt)
	if rainbowActive and light and #visualParts > 0 then
		rainbowHue = (rainbowHue + dt * 0.20) % 1
		local c = Color3.fromHSV(rainbowHue, 1, 1)
		light.Color = c
		for _, part in ipairs(visualParts) do
			part.Color = c
			part.Material = Enum.Material.Neon
		end
	end
end)

-- React to both systems (IntValue + Attribute)
local tierObj = player:FindFirstChild("PickaxeTier")
if tierObj then
	tierObj.Changed:Connect(applyTierVisuals)
else
	player.ChildAdded:Connect(function(ch)
		if ch.Name == "PickaxeTier" and ch:IsA("IntValue") then
			ch.Changed:Connect(applyTierVisuals)
			applyTierVisuals()
		end
	end)
end
player:GetAttributeChangedSignal("PickaxeTier"):Connect(applyTierVisuals)

-- Lifecycle safety
tool.Equipped:Connect(applyTierVisuals)
tool.AncestryChanged:Connect(applyTierVisuals)

-- Initial
task.defer(applyTierVisuals)
