-- LocalScript inside the Pickaxe Tool
-- Makes the pickaxe visuals change per tier (color, material, glow, RGB)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local PickaxeConfig = require(ReplicatedStorage:WaitForChild("PickaxeConfig"))

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local tool = script.Parent

-- main handle (used for size + light attach)
local handle = tool:FindFirstChild("Handle")
if not handle or not handle:IsA("BasePart") then
	warn("PickaxeVisuals: Tool has no Handle BasePart; visuals will still recolor other parts.")
end

-- collect ALL visible parts in the tool (so whole pickaxe changes)
local visualParts = {}
for _, desc in ipairs(tool:GetDescendants()) do
	if desc:IsA("BasePart") then
		table.insert(visualParts, desc)
	end
end

-- store base size for handle so we can scale from it
local baseHandleSize
if handle then
	baseHandleSize = handle.Size
end

-- light for glow
local light
if handle then
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

local rainbowActive = false
local rainbowHue = 0

-- animate RGB for Obsidian (affects all parts + light)
RunService.Heartbeat:Connect(function(dt)
	if rainbowActive and light and #visualParts > 0 then
		rainbowHue = (rainbowHue + dt * 0.2) % 1
		local rgbColor = Color3.fromHSV(rainbowHue, 1, 1)

		light.Color = rgbColor
		for _, part in ipairs(visualParts) do
			part.Color = rgbColor
			part.Material = Enum.Material.Neon
		end
	end
end)

local function applyTierVisuals()
	local tierValue = player:FindFirstChild("PickaxeTier")
	if not tierValue then
		return
	end

	local tierIndex = math.clamp(tierValue.Value, 1, PickaxeConfig.GetTierCount())
	local cfg = PickaxeConfig.GetTier(tierIndex) or {}

	local color = cfg.Color or Color3.new(1, 1, 1)
	local scale = cfg.SizeScale or 1
	local glowBright = cfg.GlowBrightness or 0
	local rainbow = cfg.RainbowGlow or false

	-- size: only handle gets scaled so we don't break everything else
	if handle and baseHandleSize then
		handle.Size = baseHandleSize * scale
	end

	-- material + color for ALL parts (so whole pickaxe changes)
	for _, part in ipairs(visualParts) do
		if not rainbow then
			if glowBright > 0 then
				part.Material = Enum.Material.Neon
			else
				part.Material = Enum.Material.Metal
			end
			part.Color = color
		end
	end

	-- glow on the light
	if light then
		light.Brightness = glowBright
		light.Enabled = glowBright > 0

		if not rainbow then
			light.Color = color
		end
	end

	rainbowActive = rainbow
	if not rainbow then
		rainbowHue = 0
	end
end

-- apply when equipped (you can also see it in-hand only, which is nice)
tool.Equipped:Connect(function()
	applyTierVisuals()
end)

-- update whenever tier changes
local tierValue = player:WaitForChild("PickaxeTier")
tierValue.Changed:Connect(function()
	if tool:IsDescendantOf(character) then
		applyTierVisuals()
	end
end)

-- initial apply if they spawn with it equipped
if tool.Parent == character then
	applyTierVisuals()
end
