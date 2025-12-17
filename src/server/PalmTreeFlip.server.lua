local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local CLICK_THRESHOLD = 10
local FLIP_DURATION = 2.5
local JUMP_HEIGHT = 2.5

local function isPalmTree(instance)
	if not instance:IsA("Model") then
		return false
	end

	local name = instance.Name:lower()
	return name:find("palm tree", 1, true) ~= nil
end

local function findRootPart(model)
	if model.PrimaryPart then
		return model.PrimaryPart
	end

	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
end

local function ensureClickDetector(part)
	local detector = part:FindFirstChildOfClass("ClickDetector")
	if not detector then
		detector = Instance.new("ClickDetector")
		detector.MaxActivationDistance = 32
		detector.Parent = part
	end
	return detector
end

local function setupPalmTree(palmTree)
	if not isPalmTree(palmTree) then
		return
	end

	if palmTree:GetAttribute("PalmTreeFlipSetup") then
		return
	end

	local rootPart = findRootPart(palmTree)
	if not rootPart then
		warn(string.format("PalmTreeFlip: Palm tree \"%s\" has no BasePart to attach the ClickDetector.", palmTree:GetFullName()))
		return
	end

	local clickDetector = ensureClickDetector(rootPart)
	local clickCount = 0
	local flipping = false

	local function performFlip()
		if flipping or not palmTree.Parent then
			return
		end

		flipping = true
		clickCount = 0

		local startPivot = palmTree:GetPivot()
		local progressValue = Instance.new("NumberValue")
		progressValue.Value = 0

		local connection
		connection = progressValue:GetPropertyChangedSignal("Value"):Connect(function()
			if not palmTree.Parent then
				return
			end

			local alpha = progressValue.Value
			local heightOffset = math.sin(math.pi * alpha) * JUMP_HEIGHT
			local rotation = CFrame.Angles(-math.pi * 2 * alpha, 0, 0)
			palmTree:PivotTo(startPivot * CFrame.new(0, heightOffset, 0) * rotation)
		end)

		local tween = TweenService:Create(
			progressValue,
			TweenInfo.new(FLIP_DURATION, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Value = 1 }
		)

		tween.Completed:Connect(function()
			if connection then
				connection:Disconnect()
			end
			progressValue:Destroy()

			if palmTree.Parent then
				palmTree:PivotTo(startPivot)
			end

			flipping = false
		end)

		tween:Play()
	end

	clickDetector.MouseClick:Connect(function()
		clickCount += 1
		if clickCount >= CLICK_THRESHOLD then
			performFlip()
		end
	end)

	palmTree:SetAttribute("PalmTreeFlipSetup", true)
end

for _, descendant in ipairs(Workspace:GetDescendants()) do
	setupPalmTree(descendant)
end

Workspace.DescendantAdded:Connect(setupPalmTree)
