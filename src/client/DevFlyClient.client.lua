-- StarterPlayerScripts.DevFlyClient
-- Listens for DevFlyToggle from server and handles flying movement.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DevFlyToggleEvent = Remotes:WaitForChild("DevFlyToggle")

local flySpeed = 120       -- change this if you want faster/slower flying
local flying = false
local upHeld = false
local downHeld = false
local flyConnection

local function getCharacter()
	return player.Character or player.CharacterAdded:Wait()
end

-- Track Space (up) and LeftControl (down)
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end

	if input.KeyCode == Enum.KeyCode.Space then
		upHeld = true
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		downHeld = true
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if input.KeyCode == Enum.KeyCode.Space then
		upHeld = false
	elseif input.KeyCode == Enum.KeyCode.LeftControl then
		downHeld = false
	end
end)

local function startFly()
	if flying then return end
	flying = true

	local character = getCharacter()
	local humanoid = character:WaitForChild("Humanoid")
	local hrp = character:WaitForChild("HumanoidRootPart")

	local bv = hrp:FindFirstChild("FlyVelocity")
	if not bv then
		bv = Instance.new("BodyVelocity")
		bv.Name = "FlyVelocity"
		bv.MaxForce = Vector3.new(1e5, 1e5, 1e5)
		bv.Velocity = Vector3.new(0, 0, 0)
		bv.Parent = hrp
	end

	local bg = hrp:FindFirstChild("FlyGyro")
	if not bg then
		bg = Instance.new("BodyGyro")
		bg.Name = "FlyGyro"
		bg.MaxTorque = Vector3.new(1e5, 1e5, 1e5)
		bg.P = 9e4
		bg.CFrame = hrp.CFrame
		bg.Parent = hrp
	end

	flyConnection = RunService.RenderStepped:Connect(function()
		if not flying then return end
		if not humanoid or not hrp then return end

		local camera = Workspace.CurrentCamera
		if not camera then return end

		local moveDir = humanoid.MoveDirection
		local velocity = moveDir * flySpeed

		if upHeld then
			velocity += Vector3.new(0, flySpeed, 0)
		end
		if downHeld then
			velocity += Vector3.new(0, -flySpeed, 0)
		end

		bv.Velocity = velocity
		bg.CFrame = CFrame.new(hrp.Position, hrp.Position + camera.CFrame.LookVector)
	end)
end

local function stopFly()
	if not flying then return end
	flying = false

	if flyConnection then
		flyConnection:Disconnect()
		flyConnection = nil
	end

	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local bv = hrp:FindFirstChild("FlyVelocity")
	if bv then bv:Destroy() end

	local bg = hrp:FindFirstChild("FlyGyro")
	if bg then bg:Destroy() end
end

-- Server tells us when to start/stop flying
DevFlyToggleEvent.OnClientEvent:Connect(function(enabled)
	if enabled then
		startFly()
	else
		stopFly()
	end
end)

-- safety: stop flying on respawn
player.CharacterAdded:Connect(function()
	if flying then
		-- re-start flight on new character if server still thinks we should be flying
		startFly()
	end
end)
