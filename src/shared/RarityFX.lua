-- src/shared/RarityFX.lua
local RarityFX = {}

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
end

function RarityFX.PlayBreak(rockModel: Instance, rarityName: string)
	local primary = getPrimary(rockModel)
	if not primary then return end

	local sound = primary:FindFirstChild("RarityBreakSound")
	if sound and sound:IsA("Sound") then
		sound:Play()
	end

end

return RarityFX
