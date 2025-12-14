-- src/shared/RarityFX.lua
local RarityFX = {}

-- Strength per rarity name. This uses whatever strings your OreConfig uses.
-- If your OreConfig rarities are Stone/Bronze/etc, add those keys here too.
RarityFX.GlowStrength = {
	Common = 0.15,
	Uncommon = 0.25,
	Rare = 0.45,
	Epic = 0.7,
	Legendary = 0.95,
	Mythic = 1.25,

	-- Optional if your rarity strings are literally the ore tiers:
	Stone = 0.15,
	Bronze = 0.25,
	Silver = 0.45,
	Gold = 0.7,
	Platinum = 0.95,
	Diamond = 1.1,
	Ruby = 1.15,
	Emerald = 1.15,
	Obsidian = 1.25,
}

-- Replace these sound ids later (you can keep them the same for now)
RarityFX.BreakSounds = {
	Default = "rbxassetid://9118826043",
}

local function getPrimary(model: Instance)
	if model:IsA("Model") then
		return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	end
	return nil
end

function RarityFX.ApplyToRock(rockModel: Instance, rarityName: string, rarityColor: Color3)
	local primary = getPrimary(rockModel)
	if not primary then return end

	if rockModel:GetAttribute("RarityFXApplied") then
		return
	end
	rockModel:SetAttribute("RarityFXApplied", true)

	local glow = RarityFX.GlowStrength[rarityName] or 0.25

	-- Highlight (soft neon)
	local highlight = rockModel:FindFirstChild("RarityHighlight")
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "RarityHighlight"
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = rockModel
	end
	highlight.FillColor = rarityColor
	highlight.OutlineColor = rarityColor
	highlight.OutlineTransparency = 0.85
	highlight.FillTransparency = math.clamp(0.72 - (glow * 0.15), 0.35, 0.82)

	-- PointLight
	local light = primary:FindFirstChild("RarityLight")
	if not light then
		light = Instance.new("PointLight")
		light.Name = "RarityLight"
		light.Shadows = false
		light.Parent = primary
	end
	light.Color = rarityColor
	light.Range = 10 + (glow * 6)
	light.Brightness = 1.2 * glow

	-- Ambient particles (only for higher glow)
	local ambient = primary:FindFirstChild("RarityAmbient")
	if not ambient then
		ambient = Instance.new("ParticleEmitter")
		ambient.Name = "RarityAmbient"
		ambient.Parent = primary
	end
	ambient.Enabled = glow >= 0.4
	ambient.Texture = "rbxassetid://296874871"
	ambient.Color = ColorSequence.new(rarityColor)
	ambient.Rate = glow >= 0.9 and 10 or 5
	ambient.Lifetime = NumberRange.new(0.4, 0.9)
	ambient.Speed = NumberRange.new(0.6, 1.2)
	ambient.SpreadAngle = Vector2.new(180, 180)
	ambient.Rotation = NumberRange.new(0, 360)
	ambient.RotSpeed = NumberRange.new(-60, 60)
	ambient.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.12),
		NumberSequenceKeypoint.new(1, 0),
	})
	ambient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})

	-- Break sound
	local sound = primary:FindFirstChild("RarityBreakSound")
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "RarityBreakSound"
		sound.Volume = 0.65
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = 70
		sound.RollOffMinDistance = 6
		sound.Parent = primary
	end
	sound.SoundId = RarityFX.BreakSounds.Default

	-- Burst template
	local burstTemplate = primary:FindFirstChild("RarityBurstTemplate")
	if not burstTemplate then
		burstTemplate = Instance.new("ParticleEmitter")
		burstTemplate.Name = "RarityBurstTemplate"
		burstTemplate.Enabled = false
		burstTemplate.Texture = "rbxassetid://296874871"
		burstTemplate.Color = ColorSequence.new(rarityColor)
		burstTemplate.Lifetime = NumberRange.new(0.3, 0.9)
		burstTemplate.Speed = NumberRange.new(14, 26)
		burstTemplate.SpreadAngle = Vector2.new(180, 180)
		burstTemplate.Rotation = NumberRange.new(0, 360)
		burstTemplate.RotSpeed = NumberRange.new(-120, 120)
		burstTemplate.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 0),
		})
		burstTemplate.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		burstTemplate.Parent = primary
	end
end

function RarityFX.PlayBreak(rockModel: Instance, rarityName: string)
	local primary = getPrimary(rockModel)
	if not primary then return end

	local sound = primary:FindFirstChild("RarityBreakSound")
	if sound and sound:IsA("Sound") then
		sound:Play()
	end

	local template = primary:FindFirstChild("RarityBurstTemplate")
	if template and template:IsA("ParticleEmitter") then
		local burst = template:Clone()
		burst.Name = "RarityBurst"
		burst.Parent = primary

		local glow = RarityFX.GlowStrength[rarityName] or 0.25
		local count = math.floor(18 + (glow * 25))
		burst:Emit(count)

		task.delay(1.5, function()
			if burst then burst:Destroy() end
		end)
	end
end

return RarityFX
