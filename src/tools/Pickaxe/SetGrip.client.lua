-- ReplicatedStorage/Tools/Pickaxe/SetGrip
local tool = script.Parent
local GRIP_ANGLE_X = math.rad(-15)
local GRIP_ANGLE_Y = math.rad(-90)
local GRIP_ANGLE_Z = math.rad(10)
local GRIP_OFFSET  = Vector3.new(0, -0.45, -0.35)

tool.Equipped:Connect(function()
	tool.Grip = CFrame.new(GRIP_OFFSET) * CFrame.Angles(GRIP_ANGLE_X, GRIP_ANGLE_Y, GRIP_ANGLE_Z)
end)
