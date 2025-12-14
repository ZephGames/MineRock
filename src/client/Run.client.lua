local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local humanoid = char:WaitForChild("Humanoid")

local WALK_SPEED = 16
local RUN_SPEED = 32

humanoid.WalkSpeed = WALK_SPEED

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = RUN_SPEED
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.LeftShift then
		humanoid.WalkSpeed = WALK_SPEED
	end
end)
