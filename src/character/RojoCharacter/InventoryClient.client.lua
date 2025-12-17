-- InventoryClient (FULL)
-- Responsive UI scaling + exposes InventoryGui.SetOpen (BindableEvent) for sidebar tabs.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Prevent duplicates on respawn
local existing = playerGui:FindFirstChild("InventoryGui")
if existing and existing:FindFirstChild("SetOpen") then
	return
end

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdateEvent = Remotes:WaitForChild("InventoryUpdate")
local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local OreConfig = require(Shared:WaitForChild("OreConfig"))

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

-- Custom order
local oreOrder = { "Stone","Bronze","Silver","Gold","Platinum","Emerald","Ruby","Diamond","Obsidian" }
local oreNames = {}
for _, name in ipairs(oreOrder) do
	if OreConfig[name] then
		table.insert(oreNames, name)
	end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "InventoryGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.DisplayOrder = 110
screenGui.Enabled = false
screenGui.Parent = playerGui

setupUIScale(screenGui)

local panelWidth = 320
local panelHeight = 675

-- This is where the panel slides to when open (leave room for sidebar tabs)
local OPEN_X = 204

local panel = Instance.new("Frame")
panel.Name = "InventoryPanel"
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

local shadow = Instance.new("Frame")
shadow.Name = "Shadow"
shadow.BackgroundColor3 = Color3.new(0, 0, 0)
shadow.BackgroundTransparency = 0.8
shadow.BorderSizePixel = 0
shadow.AnchorPoint = Vector2.new(0, 0.5)
shadow.Size = UDim2.new(0, panelWidth + 16, 0, panelHeight + 16)
shadow.ZIndex = panel.ZIndex - 1
shadow.Visible = false
shadow.Parent = screenGui

local shadowCorner = Instance.new("UICorner")
shadowCorner.CornerRadius = UDim.new(0, 16)
shadowCorner.Parent = shadow

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Size = UDim2.new(1, -20, 0, 34)
titleLabel.Position = UDim2.new(0, 14, 0, 10)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextColor3 = Color3.fromRGB(235, 235, 255)
titleLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
titleLabel.TextStrokeTransparency = 0.4
titleLabel.TextSize = 22
titleLabel.Text = "Inventory"
titleLabel.Parent = panel

local divider = Instance.new("Frame")
divider.BackgroundColor3 = Color3.fromRGB(80, 80, 120)
divider.BackgroundTransparency = 0.4
divider.BorderSizePixel = 0
divider.Size = UDim2.new(1, -28, 0, 1)
divider.Position = UDim2.new(0, 14, 0, 44)
divider.Parent = panel

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "OresScroll"
scrollFrame.BackgroundTransparency = 1
scrollFrame.BorderSizePixel = 0
scrollFrame.Position = UDim2.new(0, 14, 0, 50)
scrollFrame.Size = UDim2.new(1, -28, 1, -64)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.AutomaticCanvasSize = Enum.AutomaticSize.Y
scrollFrame.ScrollBarThickness = 0
scrollFrame.Parent = panel

local scrollPadding = Instance.new("UIPadding")
scrollPadding.PaddingTop = UDim.new(0, 4)
scrollPadding.PaddingBottom = UDim.new(0, 4)
scrollPadding.Parent = scrollFrame

local listLayout = Instance.new("UIListLayout")
listLayout.FillDirection = Enum.FillDirection.Vertical
listLayout.HorizontalAlignment = Enum.HorizontalAlignment.Left
listLayout.VerticalAlignment = Enum.VerticalAlignment.Top
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scrollFrame

local rarityColors = OreConfig.RarityColors or {}
local slots = {}

for index, oreName in ipairs(oreNames) do
	local config = OreConfig[oreName]
	local displayName = config.DisplayName or oreName
	local img = config.ImageId or ""
	local rarity = config.Rarity
	local rarityColor = rarityColors[rarity] or Color3.new(1, 1, 1)

	local slot = Instance.new("Frame")
	slot.Name = oreName .. "Slot"
	slot.BackgroundColor3 = Color3.fromRGB(30, 30, 50)
	slot.BackgroundTransparency = 0.05
	slot.BorderSizePixel = 0
	slot.Size = UDim2.new(1, 0, 0, 60)
	slot.LayoutOrder = index
	slot.Parent = scrollFrame

	local slotCorner = Instance.new("UICorner")
	slotCorner.CornerRadius = UDim.new(0, 8)
	slotCorner.Parent = slot

	local slotStroke = Instance.new("UIStroke")
	slotStroke.Thickness = 1
	slotStroke.Color = Color3.fromRGB(90, 90, 140)
	slotStroke.Transparency = 0.3
	slotStroke.Parent = slot

	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.BackgroundTransparency = 1
	icon.Size = UDim2.new(0, 40, 0, 40)
	icon.Position = UDim2.new(0, 8, 0.5, -20)
	icon.Image = img
	icon.Parent = slot

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "Name"
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, -72, 0, 22)
	nameLabel.Position = UDim2.new(0, 56, 0, 4)
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = rarityColor
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.TextScaled = true
	nameLabel.Text = displayName
	nameLabel.Parent = slot

	local amountLabel = Instance.new("TextLabel")
	amountLabel.Name = "Amount"
	amountLabel.BackgroundTransparency = 1
	amountLabel.Size = UDim2.new(0.5, -56, 0, 20)
	amountLabel.Position = UDim2.new(0, 56, 0, 32)
	amountLabel.Font = Enum.Font.Gotham
	amountLabel.TextXAlignment = Enum.TextXAlignment.Left
	amountLabel.TextColor3 = Color3.fromRGB(235, 235, 235)
	amountLabel.TextStrokeTransparency = 0.5
	amountLabel.TextScaled = true
	amountLabel.Text = "x0"
	amountLabel.Parent = slot

	slots[oreName] = { amountLabel = amountLabel }
end

local tweenTime = 0.25
local isOpen = false

local closedPosition = UDim2.new(0, -panelWidth, 0.5, 0)
local openPosition   = UDim2.new(0, OPEN_X,      0.5, 0)

local closedShadowPos = UDim2.new(0, -panelWidth - 8, 0.5, 4)
local openShadowPos   = UDim2.new(0, OPEN_X - 8,      0.5, 4)

panel.Position = closedPosition
shadow.Position = closedShadowPos

local function setOpen(open)
	if isOpen == open then return end
	isOpen = open

	shadow.Visible = open

	TweenService:Create(panel, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = open and openPosition or closedPosition
	}):Play()

	TweenService:Create(shadow, TweenInfo.new(tweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = open and openShadowPos or closedShadowPos
	}):Play()
end

-- Expose to sidebar
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

InventoryUpdateEvent.OnClientEvent:Connect(function(oreType, newAmount)
	local slot = slots[oreType]
	if slot and slot.amountLabel then
		slot.amountLabel.Text = "x" .. tostring(newAmount)
	end
end)
