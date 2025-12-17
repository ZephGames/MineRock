local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer

local CORE_GUIS = {
	Enum.CoreGuiType.Backpack,
	Enum.CoreGuiType.Health,
	Enum.CoreGuiType.PlayerList,
	Enum.CoreGuiType.Chat,
}

local function enableCoreGuis()
	for _, guiType in ipairs(CORE_GUIS) do
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, guiType, true)
	end
end

enableCoreGuis()
player.CharacterAdded:Connect(function()
	task.defer(enableCoreGuis)
end)
