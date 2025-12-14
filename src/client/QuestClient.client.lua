-- QuestClient (FULL)
-- Responsive UI scaling + exposes QuestGui.SetOpen (BindableEvent) for sidebar tabs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Prevent duplicates on respawn
local existing = playerGui:FindFirstChild("QuestGui")
if existing and existing:FindFirstChild("SetOpen") then
	return
end

local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))
local active = player:WaitForChild("ActiveQuest")
local progress = player:WaitForChild("QuestProgress")

-- ===== Responsive scaling helper =====
local function setupUIScale(screenGui)
	local uiScale = screenGui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	uiScale.Parent = screenGui

	local cam = Workspace.CurrentCamera
	local function update()
		local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		local scale = math.min(vs.X / 1920, vs.Y / 1080)
		uiScale.Scale = math.clamp(scale, 0.50, 1.05)
	end

	update()
	if cam then
		cam:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "QuestGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 110
screenGui.Enabled = false
screenGui.Parent = playerGui

setupUIScale(screenGui)

local panelWidth = 320
local panelHeight = 180
local OPEN_X = 204

local panel = Instance.new("Frame")
panel.Name = "QuestPanel"
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 25)
panel.BackgroundTransparency = 0.05
panel.BorderSizePixel = 0
panel.AnchorPoint = Vector2.new(0, 0.5)
panel.Size = UDim2.new(0, panelWidth, 0, panelHeight)
panel.Parent = screenGui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 12)
panelCorner.Parent = panel

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 1
panelStroke.Color = Color3.fromRGB(70, 70, 110)
panelStroke.Transparency = 0.2
panelStroke.Parent = panel

local panelGradient = Instance.new("UIGradient")
panelGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(25, 25, 40)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 10, 20)),
})
panelGradient.Rotation = 90
panelGradient.Parent = panel

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.new(1, -20, 0, 34)
title.Position = UDim2.new(0, 14, 0, 10)
title.Font = Enum.Font.GothamBold
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.fromRGB(235, 235, 255)
title.TextStrokeTransparency = 0.4
title.TextSize = 22
title.Text = "Quests"
title.Parent = panel

local divider = Instance.new("Frame")
divider.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
divider.BackgroundTransparency = 0.4
divider.BorderSizePixel = 0
divider.Size = UDim2.new(1, -28, 0, 1)
divider.Position = UDim2.new(0, 14, 0, 44)
divider.Parent = panel

local questText = Instance.new("TextLabel")
questText.BackgroundTransparency = 1
questText.Size = UDim2.new(1, -28, 1, -56)
questText.Position = UDim2.new(0, 14, 0, 52)
questText.Font = Enum.Font.GothamSemibold
questText.TextXAlignment = Enum.TextXAlignment.Left
questText.TextYAlignment = Enum.TextYAlignment.Top
questText.TextColor3 = Color3.fromRGB(220, 220, 240)
questText.TextStrokeTransparency = 0.6
questText.TextSize = 18
questText.TextWrapped = true
questText.Text = "Loading quest..."
questText.Parent = panel

local tweenTime = 0.25
local isOpen = false

local closedPos = UDim2.new(0, -panelWidth, 0.5, 0)
local openPos   = UDim2.new(0, OPEN_X,      0.5, 0)
panel.Position = closedPos

local function setOpen(open)
	if isOpen == open then return end
	isOpen = open
	TweenService:Create(panel, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = open and openPos or closedPos
	}):Play()
end

local setOpenEvent = Instance.new("BindableEvent")
setOpenEvent.Name = "SetOpen"
setOpenEvent.Parent = screenGui

setOpenEvent.Event:Connect(function(open)
	if open then
		screenGui.Enabled = true
		setOpen(true)
	else
		setOpen(false)
		task.delay(tweenTime, function()
			if not isOpen then
				screenGui.Enabled = false
			end
		end)
	end
end)

local function updateQuestText()
	local questId = active.Value
	local prog = progress.Value

	for _, q in ipairs(QuestConfig) do
		if q.Id == questId then
			questText.Text = q.Text .. "\n" .. tostring(prog) .. "/" .. tostring(q.Target)
			return
		end
	end

	questText.Text = "No active quest"
end

active.Changed:Connect(updateQuestText)
progress.Changed:Connect(updateQuestText)
updateQuestText()
