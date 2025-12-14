-- StarterPlayerScripts.TabsClient
-- STYLE: Ultra-Modern Glassmorphism + Animated RGB
-- FEATURES: Menu (Inv/Quests), Separate Shop (Sell/Pickaxes)
-- INTEGRATION: Merged ShopClient logic + Gamepass checks

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local MarketplaceService = game:GetService("MarketplaceService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- // 1. CLEANUP & INIT //
local existingNames = { "MainRGBGui", "MainTabsGui", "InventoryGui", "QuestGui", "MenuGui", "ShopGui", "ShopTeleportGui" }
for _, n in ipairs(existingNames) do
	local g = playerGui:FindFirstChild(n)
	if g then g:Destroy() end
end

-- // 2. CONFIGURATION & REMOTES //
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdateEvent = Remotes:WaitForChild("InventoryUpdate")
local SellAllEvent = Remotes:WaitForChild("SellAll")
local RequestPickaxeUpgradeEvent = Remotes:WaitForChild("RequestPickaxeUpgrade")
local TeleportToShopEvent = Remotes:FindFirstChild("TeleportToShop")

local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local OreConfig = require(Shared:WaitForChild("OreConfig"))
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))
local PickaxeConfigModule = require(Shared:WaitForChild("PickaxeConfig"))
local PickaxeTiers = PickaxeConfigModule.Tiers or PickaxeConfigModule

-- Shop Configuration
local ShopCenter = Workspace:WaitForChild("ShopCenter") -- Ensure this part exists in Workspace
local SELL_RADIUS = 15 -- Distance to open shop
local SHOP_HIDE_RADIUS = 30 -- Distance to auto-close shop UI
local SELL_ANYWHERE_PASS_ID = 1631522468

-- Devs who can use "!pass sell" locally (add any co-dev IDs here)
local DEV_USER_IDS = {
	[2527826821] = true, -- Zephrynix_RBX (you)
}

local function isDevPlayer()
	if RunService:IsStudio() then return true end
	if DEV_USER_IDS[player.UserId] then return true end

	-- Also allow place owner (user-owned games) or high-rank group members (group-owned games)
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		return ok and rank >= 200
	end
	return false
end

local oreOrder = { "Stone","Bronze","Silver","Gold","Platinum","Emerald","Ruby","Diamond","Obsidian" }
local oreNames = {}
for _, name in ipairs(oreOrder) do
	if OreConfig[name] then table.insert(oreNames, name) end
end

-- // 3. THEME ENGINE //
local THEME = {
	Glass = Color3.fromRGB(20, 22, 30),
	GlassHover = Color3.fromRGB(35, 35, 50),
	TextMain = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(180, 180, 200),
	BorderDefault = Color3.fromRGB(255, 255, 255),
	AccentGreen = Color3.fromRGB(50, 255, 120),
	AccentBlue = Color3.fromRGB(70, 120, 220),
	Locked = Color3.fromRGB(80, 80, 90),
	Rainbow = ColorSequence.new({
		ColorSequenceKeypoint.new(0.00, Color3.fromHSV(0.00, 1, 1)),
		ColorSequenceKeypoint.new(0.20, Color3.fromHSV(0.20, 1, 1)),
		ColorSequenceKeypoint.new(0.40, Color3.fromHSV(0.40, 1, 1)),
		ColorSequenceKeypoint.new(0.60, Color3.fromHSV(0.60, 1, 1)),
		ColorSequenceKeypoint.new(0.80, Color3.fromHSV(0.80, 1, 1)),
		ColorSequenceKeypoint.new(1.00, Color3.fromHSV(0.00, 1, 1)),
	})
}

-- // 4. UTILS //
local function tween(obj, props, time, style, dir)
	TweenService:Create(obj, TweenInfo.new(time or 0.3, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out), props):Play()
end

local function startRGBSpin(grad, speed)
        local r = 0
        RunService.RenderStepped:Connect(function(dt)
                if grad.Parent then
                        r = (r + dt * (speed or 45)) % 360
			grad.Rotation = r
		end
        end)
end

local function cycleRGBColor(frame, speed)
        local hue = 0
        RunService.RenderStepped:Connect(function(dt)
                if not frame.Parent then return end
                hue = (hue + dt * (speed or 0.2)) % 1
                frame.BackgroundColor3 = Color3.fromHSV(hue, 1, 1)
        end)
end

-- Used for Text RGB
local function startTextColorSpin(textLabel)
	local h = 0
	RunService.RenderStepped:Connect(function(dt)
		if textLabel.Parent then
			h = (h + dt * 0.2) % 1
			textLabel.TextColor3 = Color3.fromHSV(h, 0.8, 1)
		end
	end)
end

-- // 5. UI COMPONENTS //
local function createCorner(p, r)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r or 12)
	c.Parent = p
	return c
end

local function createStroke(p, color, thick, transp)
	local s = Instance.new("UIStroke")
	s.Color = color or THEME.BorderDefault
	s.Thickness = thick or 1.5
	s.Transparency = transp or 0.8
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = p
	return s
end

-- Updated: Stroke Transparency is 0 for maximum visibility of RGB
local function createGlassPanel(parent, size, pos)
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = THEME.Glass
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Size = size
	frame.Position = pos or UDim2.new(0,0,0,0)
	frame.Parent = parent

	createCorner(frame, 16)

	-- The Stroke containing the RGB Gradient
	local s = createStroke(frame, THEME.BorderDefault, 2.5, 0)

	-- Add Rainbow Gradient to Panel Stroke
	local g = Instance.new("UIGradient")
	g.Color = THEME.Rainbow
	g.Parent = s
	startRGBSpin(g)

	return frame
end

local function createGlassButton(parent, text, size)
	local btn = Instance.new("TextButton")
	btn.Name = text
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BackgroundColor3 = THEME.Glass
	btn.BackgroundTransparency = 0.3
	btn.Size = size or UDim2.new(1, 0, 0, 50)
	btn.Parent = parent

	createCorner(btn, 12)
	local stroke = createStroke(btn, THEME.BorderDefault, 1.5, 0.8)

	-- Rainbow Gradient for Stroke (Hidden by default)
	local gradient = Instance.new("UIGradient")
	gradient.Color = THEME.Rainbow
	gradient.Enabled = false
	gradient.Parent = stroke
	startRGBSpin(gradient)

	-- Content Container
	local content = Instance.new("Frame")
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, 0, 1, 0)
	content.Parent = btn

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Position = UDim2.new(0, 0, 0, 0)
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = THEME.TextMain
	label.TextSize = 18 -- Larger font
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.Parent = content

	-- Interaction
	btn.MouseEnter:Connect(function()
		if btn.Active then
			tween(btn, {BackgroundTransparency = 0.1, BackgroundColor3 = THEME.GlassHover}, 0.2)
			gradient.Enabled = true
			stroke.Transparency = 0
			stroke.Thickness = 2.5
			tween(content, {Size = UDim2.new(1.05, 0, 1.05, 0)}, 0.2)
		end
	end)

	btn.MouseLeave:Connect(function()
		if btn:GetAttribute("Selected") then return end
		tween(btn, {BackgroundTransparency = 0.3, BackgroundColor3 = THEME.Glass}, 0.3)
		gradient.Enabled = false
		stroke.Transparency = 0.8
		stroke.Thickness = 1.5
		tween(content, {Size = UDim2.new(1, 0, 1, 0)}, 0.3)
	end)

	btn.MouseButton1Down:Connect(function()
		if btn.Active then
			tween(content, {Size = UDim2.new(0.95, 0, 0.95, 0)}, 0.05)
		end
	end)

	btn.MouseButton1Up:Connect(function()
		if btn.Active then
			tween(content, {Size = UDim2.new(1.05, 0, 1.05, 0)}, 0.1)
		end
	end)

	return btn, stroke, gradient, label
end

-- // 6. MAIN GUI ASSEMBLY //
local gui = Instance.new("ScreenGui")
gui.Name = "MainRGBGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = playerGui

-- ==========================================
-- 6a. MENU SYSTEM (Inventory / Quests)
-- ==========================================

-- Trigger Button
local menuTriggerFrame = Instance.new("Frame")
menuTriggerFrame.Size = UDim2.new(0, 80, 0, 80)
menuTriggerFrame.Position = UDim2.new(0, 20, 0.5, -40)
menuTriggerFrame.BackgroundTransparency = 1
menuTriggerFrame.Parent = gui

local menuBtn, mStroke, mGrad, mLabel = createGlassButton(menuTriggerFrame, "MENU", UDim2.new(1,0,1,0))
mLabel.TextSize = 22

local isMenuOpen = false

-- Menu Main Frame (Off-screen start)
local menuFrame = Instance.new("Frame")
menuFrame.Name = "MenuFrame"
menuFrame.Size = UDim2.new(0.7, 0, 0.7, 0) -- Slightly Larger
menuFrame.Position = UDim2.new(-1, 0, 0.5, 0) -- Hidden Left
menuFrame.AnchorPoint = Vector2.new(0.5, 0.5)
menuFrame.BackgroundTransparency = 1
menuFrame.Parent = gui

local menuScale = Instance.new("UIScale")
menuScale.Parent = menuFrame

-- Sidebar (Left)
local menuSidebar = createGlassPanel(menuFrame, UDim2.new(0.25, -15, 1, 0), UDim2.new(0, 0, 0, 0))
local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 10)
sidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sidebarLayout.Parent = menuSidebar
local sidebarPad = Instance.new("UIPadding")
sidebarPad.PaddingTop = UDim.new(0, 20)
sidebarPad.Parent = menuSidebar

local menuTitle = Instance.new("TextLabel")
menuTitle.Text = "MENU"
menuTitle.Font = Enum.Font.GothamBlack
menuTitle.TextSize = 30
menuTitle.TextColor3 = THEME.TextMain
menuTitle.BackgroundTransparency = 1
menuTitle.Size = UDim2.new(1,0,0,50)
menuTitle.Parent = menuSidebar

-- Content (Right)
local menuContent = createGlassPanel(menuFrame, UDim2.new(0.75, 0, 1, 0), UDim2.new(0.25, 15, 0, 0))
local contentPad = Instance.new("UIPadding")
contentPad.PaddingTop = UDim.new(0, 20)
contentPad.PaddingBottom = UDim.new(0, 20)
contentPad.PaddingLeft = UDim.new(0, 20)
contentPad.PaddingRight = UDim.new(0, 20)
contentPad.Parent = menuContent

-- Tabs Logic
local menuTabs = {}
local menuPages = {}

local function createMenuPage(name)
	local page = Instance.new("Frame")
	page.Name = name .. "Page"
	page.BackgroundTransparency = 1
	page.Size = UDim2.new(1, 0, 1, 0)
	page.Visible = false
	page.Parent = menuContent
	menuPages[name] = page
	return page
end

local function switchMenuTab(name)
	for n, p in pairs(menuPages) do p.Visible = false end
	for n, data in pairs(menuTabs) do
		local isMe = (n == name)
		data.Btn:SetAttribute("Selected", isMe)
		if isMe then
			tween(data.Btn, {BackgroundTransparency = 0.1, BackgroundColor3 = THEME.GlassHover}, 0.2)
			data.Stroke.Transparency = 0
			data.Grad.Enabled = true
		else
			tween(data.Btn, {BackgroundTransparency = 0.3, BackgroundColor3 = THEME.Glass}, 0.2)
			data.Stroke.Transparency = 0.8
			data.Grad.Enabled = false
		end
	end
	if menuPages[name] then
		menuPages[name].Visible = true
		menuPages[name].Position = UDim2.new(0,0,0.05,0)
		tween(menuPages[name], {Position = UDim2.new(0,0,0,0)}, 0.3, Enum.EasingStyle.Back)
	end
end

local function addMenuTab(name)
	local btn, stroke, grad = createGlassButton(menuSidebar, name, UDim2.new(0.9, 0, 0, 50))
	local page = createMenuPage(name)
	menuTabs[name] = {Btn = btn, Stroke = stroke, Grad = grad}
	btn.MouseButton1Click:Connect(function() switchMenuTab(name) end)
	return page
end

local invPage = addMenuTab("Inventory")
local questPage = addMenuTab("Quests")

-- Inventory Page Content (3x3 Grid, Fixed Sizing)
local invScroll = Instance.new("Frame")
invScroll.BackgroundTransparency = 1
invScroll.Size = UDim2.new(1, 0, 1, 0)
invScroll.Parent = invPage

local invGrid = Instance.new("UIGridLayout")
invGrid.CellPadding = UDim2.new(0.02, 0, 0.02, 0)
invGrid.CellSize = UDim2.new(0.32, 0, 0.31, 0) -- Fits 3x3 perfectly
invGrid.FillDirection = Enum.FillDirection.Horizontal
invGrid.SortOrder = Enum.SortOrder.LayoutOrder
invGrid.Parent = invScroll

local invSlots = {}
for i, oreName in ipairs(oreNames) do
	local cfg = OreConfig[oreName]
	local slot = Instance.new("Frame")
	slot.BackgroundColor3 = THEME.Glass
	slot.BackgroundTransparency = 0.4
	slot.LayoutOrder = i
	slot.Parent = invScroll
	createCorner(slot, 12)
	createStroke(slot, THEME.BorderDefault, 1, 0.9)

	-- BIG IMAGE (Left)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(0.65, 0, 0.65, 0) -- Adjusted size
	img.SizeConstraint = Enum.SizeConstraint.RelativeYY
	img.AnchorPoint = Vector2.new(0, 0.5)
	img.Position = UDim2.new(0.05, 0, 0.5, 0)
	img.Image = cfg.ImageId or ""
	img.ScaleType = Enum.ScaleType.Fit
	img.Parent = slot

	-- AMOUNT (Right Top)
	local amt = Instance.new("TextLabel")
	amt.Text = "0"
	amt.Font = Enum.Font.GothamBlack
	amt.TextColor3 = THEME.TextMain
	amt.BackgroundTransparency = 1
	amt.Size = UDim2.new(0.55, 0, 0.4, 0)
	amt.Position = UDim2.new(0.4, 0, 0.2, 0)
	amt.TextSize = 32
	amt.TextXAlignment = Enum.TextXAlignment.Center
	amt.TextYAlignment = Enum.TextYAlignment.Bottom
	amt.Parent = slot

	-- NAME (Right Bottom - Below Number)
	local name = Instance.new("TextLabel")
	name.Text = cfg.DisplayName or oreName
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = THEME.TextDim
	name.TextSize = 16
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(0.55, 0, 0.3, 0)
	name.Position = UDim2.new(0.4, 0, 0.6, 0)
	name.TextXAlignment = Enum.TextXAlignment.Center
	name.TextYAlignment = Enum.TextYAlignment.Top
	name.Parent = slot

	invSlots[oreName] = amt
end

-- Quests Page Content (Current + Next)
local qTitle = Instance.new("TextLabel")
qTitle.Text = "CURRENT MISSION"
qTitle.Font = Enum.Font.GothamBlack
qTitle.TextSize = 26
qTitle.TextColor3 = THEME.AccentGreen
qTitle.BackgroundTransparency = 1
qTitle.Size = UDim2.new(1,0,0,30)
qTitle.Parent = questPage

local qDesc = Instance.new("TextLabel")
qDesc.Text = "Loading..."
qDesc.Font = Enum.Font.GothamBold
qDesc.TextSize = 22
qDesc.TextColor3 = THEME.TextMain
qDesc.BackgroundTransparency = 1
qDesc.Size = UDim2.new(1,0,0,60)
qDesc.Position = UDim2.new(0,0,0,40)
qDesc.TextWrapped = true
qDesc.Parent = questPage

local barBg = Instance.new("Frame")
barBg.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
barBg.BackgroundTransparency = 0.35
barBg.Size = UDim2.new(1,0,0,24)
barBg.Position = UDim2.new(0,0,0,110)
barBg.Parent = questPage
createCorner(barBg, 10)

local barFill = Instance.new("Frame")
barFill.BackgroundColor3 = THEME.AccentGreen
barFill.Size = UDim2.new(0,0,1,0)
barFill.Parent = barBg
createCorner(barFill, 10)

cycleRGBColor(barFill, 0.35)

local qProgressText = Instance.new("TextLabel")
qProgressText.Text = "0 / 0"
qProgressText.Font = Enum.Font.GothamBold
qProgressText.TextColor3 = THEME.TextMain
qProgressText.TextSize = 16
qProgressText.BackgroundTransparency = 1
qProgressText.Size = UDim2.new(1,0,1,0)
qProgressText.Parent = barBg

-- UPCOMING QUESTS SECTION
local nextQTitle = Instance.new("TextLabel")
nextQTitle.Text = "UPCOMING"
nextQTitle.Font = Enum.Font.GothamBold
nextQTitle.TextSize = 18
nextQTitle.TextColor3 = THEME.TextDim
nextQTitle.BackgroundTransparency = 1
nextQTitle.Size = UDim2.new(1,0,0,30)
nextQTitle.Position = UDim2.new(0,0,0,160)
nextQTitle.TextXAlignment = Enum.TextXAlignment.Left
nextQTitle.Parent = questPage

local nextQScroll = Instance.new("ScrollingFrame")
nextQScroll.BackgroundTransparency = 1
nextQScroll.Size = UDim2.new(1, 0, 1, -200)
nextQScroll.Position = UDim2.new(0, 0, 0, 200)
nextQScroll.ScrollBarThickness = 4
nextQScroll.CanvasSize = UDim2.new(0,0,0,0)
nextQScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
nextQScroll.Parent = questPage

local nextQLayout = Instance.new("UIListLayout")
nextQLayout.Padding = UDim.new(0, 8)
nextQLayout.Parent = nextQScroll

local upcomingLabels = {} -- Store frames to update them

-- ==========================================
-- 6b. SHOP SYSTEM
-- ==========================================

local shopOverlay = Instance.new("Frame")
shopOverlay.Name = "ShopOverlay"
shopOverlay.Size = UDim2.fromScale(1, 1)
shopOverlay.BackgroundColor3 = Color3.fromRGB(6, 8, 12)
-- Remove dimming effect while keeping overlay for input capture
shopOverlay.BackgroundTransparency = 1
shopOverlay.Visible = false
shopOverlay.ZIndex = 5
shopOverlay.Parent = gui

local shopFrame = Instance.new("Frame")
shopFrame.Name = "ShopFrame"
shopFrame.Size = UDim2.new(0.65, 0, 0.65, 0)
shopFrame.Position = UDim2.new(0.5, 0, 1.5, 0) -- Hidden Bottom
shopFrame.AnchorPoint = Vector2.new(0.5, 0.5)
shopFrame.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
shopFrame.BackgroundTransparency = 0.15
shopFrame.BorderSizePixel = 0
shopFrame.ZIndex = 6
shopFrame.Parent = shopOverlay
createCorner(shopFrame, 18)
createStroke(shopFrame, THEME.BorderDefault, 1.5, 0.7)

local shopPadding = Instance.new("UIPadding")
shopPadding.PaddingTop = UDim.new(0, 16)
shopPadding.PaddingBottom = UDim.new(0, 16)
shopPadding.PaddingLeft = UDim.new(0, 16)
shopPadding.PaddingRight = UDim.new(0, 16)
shopPadding.Parent = shopFrame

local shopScale = Instance.new("UIScale")
shopScale.Parent = shopFrame

-- Shop Sidebar (Left)
local shopSidebar = createGlassPanel(shopFrame, UDim2.new(0.25, -10, 1, 0), UDim2.new(0, 0, 0, 0))
local shopSidebarLayout = Instance.new("UIListLayout")
shopSidebarLayout.Padding = UDim.new(0, 10)
shopSidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
shopSidebarLayout.Parent = shopSidebar
local shopSidebarPad = Instance.new("UIPadding")
shopSidebarPad.PaddingTop = UDim.new(0, 20)
shopSidebarPad.Parent = shopSidebar

-- Shop Title Area
local shopTitleFrame = Instance.new("Frame")
shopTitleFrame.Size = UDim2.new(1, 0, 0, 90)
shopTitleFrame.BackgroundTransparency = 1
shopTitleFrame.Parent = shopSidebar

local shopTitle = Instance.new("TextLabel")
shopTitle.Text = "SHOP"
shopTitle.Font = Enum.Font.GothamBlack
shopTitle.TextSize = 34
shopTitle.TextColor3 = THEME.TextMain
shopTitle.BackgroundTransparency = 1
shopTitle.Size = UDim2.new(1,0,0,30)
shopTitle.Parent = shopTitleFrame

local shopSubtitle = Instance.new("TextLabel")
shopSubtitle.Text = "Sell ores or upgrade your tools"
shopSubtitle.Font = Enum.Font.Gotham
shopSubtitle.TextSize = 16
shopSubtitle.TextColor3 = THEME.TextDim
shopSubtitle.BackgroundTransparency = 1
shopSubtitle.Size = UDim2.new(1,0,0,18)
shopSubtitle.Position = UDim2.new(0,0,0,32)
shopSubtitle.TextWrapped = true
shopSubtitle.Parent = shopTitleFrame

local shopCoins = Instance.new("TextLabel")
shopCoins.Text = "Coins: 0"
shopCoins.Font = Enum.Font.GothamBold
shopCoins.TextSize = 20
shopCoins.TextColor3 = THEME.AccentGreen
shopCoins.BackgroundTransparency = 1
shopCoins.Size = UDim2.new(1,0,0,20)
shopCoins.Position = UDim2.new(0,0,0,54)
shopCoins.Parent = shopTitleFrame

-- Shop Tabs Logic (using buttons in sidebar)
local shopTabBtns = {}
local shopPages = {}

local function switchShopTab(name)
	for n, p in pairs(shopPages) do p.Visible = false end
	for n, btn in pairs(shopTabBtns) do
		local isMe = (n == name)
		if isMe then
			tween(btn, {BackgroundTransparency = 0.1, BackgroundColor3 = THEME.GlassHover}, 0.2)
		else
			tween(btn, {BackgroundTransparency = 0.3, BackgroundColor3 = THEME.Glass}, 0.2)
		end
	end
	if shopPages[name] then
		shopPages[name].Visible = true
	end
end

-- Shop Content (Right)
local shopContent = createGlassPanel(shopFrame, UDim2.new(0.75, 0, 1, 0), UDim2.new(0.25, 12, 0, 0))
local shopContentPad = Instance.new("UIPadding")
shopContentPad.PaddingTop = UDim.new(0, 20)
shopContentPad.PaddingBottom = UDim.new(0, 20)
shopContentPad.PaddingLeft = UDim.new(0, 20)
shopContentPad.PaddingRight = UDim.new(0, 20)
shopContentPad.Parent = shopContent

-- Create Tab Buttons in Sidebar
local btnSell = createGlassButton(shopSidebar, "Sell Ores", UDim2.new(0.9, 0, 0, 50))
shopTabBtns["Sell"] = btnSell
local btnPicks = createGlassButton(shopSidebar, "Pickaxes", UDim2.new(0.9, 0, 0, 50))
shopTabBtns["Pickaxes"] = btnPicks

-- Pages
local sellPageFrame = Instance.new("Frame")
sellPageFrame.BackgroundTransparency = 1
sellPageFrame.Size = UDim2.new(1, 0, 1, 0)
sellPageFrame.Parent = shopContent
shopPages["Sell"] = sellPageFrame

local sellView = Instance.new("ScrollingFrame")
sellView.BackgroundTransparency = 1
sellView.Size = UDim2.new(1, -12, 1, -60) -- Leave space for Sell button at bottom, and scrollbar
sellView.ScrollBarThickness = 4
sellView.AutomaticCanvasSize = Enum.AutomaticSize.Y
sellView.Parent = sellPageFrame

local sellViewPad = Instance.new("UIPadding")
sellViewPad.PaddingTop = UDim.new(0, 8)
sellViewPad.PaddingBottom = UDim.new(0, 8)
sellViewPad.PaddingLeft = UDim.new(0, 6)
sellViewPad.PaddingRight = UDim.new(0, 6)
sellViewPad.Parent = sellView

local pickView = Instance.new("ScrollingFrame")
pickView.BackgroundTransparency = 1
pickView.Size = UDim2.new(1, -12, 1, 0)
pickView.ScrollBarThickness = 4
pickView.Visible = false
pickView.AutomaticCanvasSize = Enum.AutomaticSize.Y
pickView.Parent = shopContent
shopPages["Pickaxes"] = pickView

btnSell.MouseButton1Click:Connect(function() switchShopTab("Sell") end)
btnPicks.MouseButton1Click:Connect(function() switchShopTab("Pickaxes") end)

-- Close Button (Absolute positioned on ShopFrame to overlap right corner)
local shopCloseBtn, scStroke, scGrad, scLbl = createGlassButton(shopFrame, "X", UDim2.new(0, 40, 0, 40))
shopCloseBtn.Position = UDim2.new(1, -25, 0, -15) -- Top Right Corner
shopCloseBtn.ZIndex = 10
scLbl.TextSize = 22

local isShopOpen = false

-- SELL VIEW CONTENT
local sellLayout = Instance.new("UIListLayout")
sellLayout.Padding = UDim.new(0, 5)
sellLayout.Parent = sellView

for _, oreName in ipairs(oreNames) do
	local cfg = OreConfig[oreName]
	local row = Instance.new("Frame")
	row.BackgroundColor3 = THEME.Glass
        row.BackgroundTransparency = 0.35
        row.Size = UDim2.new(1, 0, 0, 64) -- Slightly taller
        row.Parent = sellView
        createCorner(row, 8)
        createStroke(row, THEME.BorderDefault, 1, 0.7)

	-- ADDED ORE IMAGE
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(0, 45, 0, 45)
	img.Position = UDim2.new(0, 10, 0.5, -22)
	img.Image = cfg.ImageId or ""
	img.Parent = row

	local lbl = Instance.new("TextLabel")
	lbl.Text = cfg.DisplayName or oreName
	lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 19
        lbl.TextColor3 = THEME.TextMain
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Size = UDim2.new(0.4, 0, 1, 0)
	lbl.Position = UDim2.new(0, 65, 0, 0) -- Shifted right
	lbl.BackgroundTransparency = 1
	lbl.Parent = row

	local val = Instance.new("TextLabel")
        val.Text = "Value: " .. (cfg.Value or 0)
        val.Font = Enum.Font.GothamSemibold
        val.TextSize = 18
        val.TextColor3 = THEME.AccentGreen
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Size = UDim2.new(0.4, 0, 1, 0) -- Reduced width to pull away from edge
        val.Position = UDim2.new(0.55, 0, 0, 0) -- Shifted left
	val.BackgroundTransparency = 1
	val.Parent = row
end

-- SELL ALL BUTTON (At bottom of Sell Page, NOT sidebar)
local sellAllBtn, saStroke, saGrad, saLbl = createGlassButton(sellPageFrame, "SELL ALL", UDim2.new(1, 0, 0, 50))
sellAllBtn.Position = UDim2.new(0, 0, 1, -50)
sellAllBtn.BackgroundColor3 = THEME.AccentGreen
sellAllBtn.ZIndex = 5
saLbl.TextSize = 22

sellAllBtn.MouseButton1Click:Connect(function()
	SellAllEvent:FireServer()
	tween(sellAllBtn, {BackgroundColor3 = Color3.fromRGB(255, 255, 255)}, 0.1)
	saLbl.Text = "SOLD!"
	task.wait(0.5)
	tween(sellAllBtn, {BackgroundColor3 = THEME.AccentGreen}, 0.5)
	saLbl.Text = "SELL ALL"
end)

-- PICKAXES CONTENT
local pickLayout = Instance.new("UIListLayout")
pickLayout.Padding = UDim.new(0, 10)
pickLayout.Parent = pickView

-- Add padding to bottom of pickaxe view so last item isn't cut off
local pickPad = Instance.new("UIPadding")
pickPad.PaddingBottom = UDim.new(0, 10)
pickPad.Parent = pickView

local pickaxeUI = {}

for idx, tool in ipairs(PickaxeTiers) do
	local row = Instance.new("Frame")
	row.BackgroundColor3 = THEME.Glass
	row.BackgroundTransparency = 0.3
	row.Size = UDim2.new(1, -10, 0, 100) -- Taller to fit image
	row.Parent = pickView
	createCorner(row, 12)
	createStroke(row, THEME.BorderDefault, 1, 0.8)

	-- IMAGE
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.new(0, 80, 0, 80)
	img.Position = UDim2.new(0, 10, 0.5, -40)
	-- Placeholder image if none in config, or use tool.Image
	img.Image = tool.Image or "rbxassetid://0"
	img.Parent = row

	local name = Instance.new("TextLabel")
	name.Text = tool.DisplayName or tool.Name
	name.Font = Enum.Font.GothamBold
	name.TextSize = 20
	name.TextColor3 = tool.Color or THEME.TextMain
	name.BackgroundTransparency = 1
	name.Size = UDim2.new(0.5, 0, 0.3, 0)
	name.Position = UDim2.new(0, 100, 0.15, 0)
	name.TextXAlignment = Enum.TextXAlignment.Left
	name.Parent = row

	-- Special RGB for Obsidian
	if (tool.Name and string.find(tool.Name, "Obsidian")) or tool.RainbowGlow then
		startTextColorSpin(name)
	end

	local stats = Instance.new("TextLabel")
	stats.Text = "Dmg: " .. (tool.Damage or 0) .. " | Spd: " .. (tool.Cooldown or 0)
	stats.Font = Enum.Font.Gotham
	stats.TextSize = 16
	stats.TextColor3 = THEME.TextDim
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(0.5, 0, 0.4, 0)
	stats.Position = UDim2.new(0, 100, 0.5, 0)
	stats.TextXAlignment = Enum.TextXAlignment.Left
	stats.Parent = row

	local buyBtn, bStroke, bGrad, bLbl = createGlassButton(row, "...", UDim2.new(0, 140, 0, 50))
	buyBtn.Position = UDim2.new(1, -150, 0.5, -25)

	buyBtn.MouseButton1Click:Connect(function()
		if buyBtn.Active then
			RequestPickaxeUpgradeEvent:FireServer(idx)
		end
	end)

	pickaxeUI[idx] = {Btn = buyBtn, Lbl = bLbl, Cost = tool.Cost or 0}
end

-- // 7. LOGIC & UPDATERS //

-- Inventory Updater
InventoryUpdateEvent.OnClientEvent:Connect(function(oreType, newAmount)
	if invSlots[oreType] then invSlots[oreType].Text = "x"..tostring(newAmount) end
end)

-- Quest Updater Logic
local function updateQuest()
	local aQ = player:WaitForChild("ActiveQuest", 5)
	local qP = player:WaitForChild("QuestProgress", 5)
	if not aQ or not qP then return end
	local qId = aQ.Value
	local prog = qP.Value

	local activeIdx = 0
	local qData = nil

	-- Find Active
	for i, q in ipairs(QuestConfig) do
		if q.Id == qId then
			qData = q
			activeIdx = i
			break
		end
	end

	-- Update Current
	if qData then
		qDesc.Text = qData.Text
		local pct = math.clamp(prog/qData.Target, 0, 1)
		tween(barFill, {Size = UDim2.new(pct, 0, 1, 0)}, 0.5, Enum.EasingStyle.Elastic)
		qProgressText.Text = prog .. " / " .. qData.Target
	else
		qDesc.Text = "All quests completed!"
		qProgressText.Text = "- / -"
		tween(barFill, {Size = UDim2.new(0, 0, 1, 0)}, 0.5)
	end

	-- Update Upcoming (Grayed Out)
	for _, l in ipairs(upcomingLabels) do l:Destroy() end
	table.clear(upcomingLabels)

	if activeIdx > 0 then
		for i = activeIdx + 1, math.min(activeIdx + 3, #QuestConfig) do
			local nextQ = QuestConfig[i]
			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 40)
			row.Parent = nextQScroll

			local lbl = Instance.new("TextLabel")
			lbl.Text = nextQ.Text
			lbl.Font = Enum.Font.GothamMedium
			lbl.TextSize = 18
			lbl.TextColor3 = THEME.Locked -- Grayed out
			lbl.BackgroundTransparency = 1
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.Parent = row

			local lockIcon = Instance.new("TextLabel")
			lockIcon.Text = "??"
			lockIcon.Font = Enum.Font.Gotham
			lockIcon.TextSize = 16
			lockIcon.BackgroundTransparency = 1
			lockIcon.Size = UDim2.new(0, 20, 1, 0)
			lockIcon.Position = UDim2.new(1, -30, 0, 0)
			lockIcon.TextColor3 = THEME.Locked
			lockIcon.Parent = row

			table.insert(upcomingLabels, row)
		end
	end
end

if player:FindFirstChild("ActiveQuest") then
	player.ActiveQuest.Changed:Connect(updateQuest)
	player.QuestProgress.Changed:Connect(updateQuest)
	task.delay(1, updateQuest)
end

-- Pickaxe Button Updater
local function updateShopButtons()
	local leaderstats = player:FindFirstChild("leaderstats")
	local coins = leaderstats and leaderstats:FindFirstChild("Coins") and leaderstats.Coins.Value or 0
	shopCoins.Text = "Coins: " .. coins

	local tierVal = player:FindFirstChild("PickaxeTier")
	local currentTier = tierVal and tierVal.Value or 1

	for idx, data in pairs(pickaxeUI) do
		local btn = data.Btn
		local lbl = data.Lbl
		local cost = data.Cost

		if idx < currentTier then
			lbl.Text = "Owned"
			btn.BackgroundColor3 = THEME.Locked
			btn.Active = false
		elseif idx == currentTier then
			lbl.Text = "Equipped"
			btn.BackgroundColor3 = THEME.AccentGreen
			btn.Active = false
		elseif idx == currentTier + 1 then
			lbl.Text = "Buy ("..cost..")"
			if coins >= cost then
				btn.BackgroundColor3 = THEME.AccentBlue
				btn.Active = true
			else
				btn.BackgroundColor3 = THEME.Locked
				btn.Active = false
			end
		else
			lbl.Text = "Locked"
			btn.BackgroundColor3 = THEME.Locked
			btn.Active = false
		end
	end
end

task.spawn(function()
	local ls = player:WaitForChild("leaderstats", 10)
	if ls then ls:WaitForChild("Coins", 10).Changed:Connect(updateShopButtons) end
	local pt = player:WaitForChild("PickaxeTier", 10)
	if pt then pt.Changed:Connect(updateShopButtons) end
	updateShopButtons()
end)

-- // 8. VISIBILITY CONTROLS //

-- Toggle Main Menu (Inventory/Quests)
local function toggleMenu()
	isMenuOpen = not isMenuOpen
	if isMenuOpen then
		local targetPos = UDim2.new(0.5, 0, 0.5, 0)
		tween(menuFrame, {Position = targetPos}, 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		tween(menuBtn, {BackgroundTransparency = 0.1, BackgroundColor3 = THEME.GlassHover}, 0.3)
		mGrad.Enabled = true
		mStroke.Transparency = 0
	else
		tween(menuFrame, {Position = UDim2.new(-1, 0, 0.5, 0)}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		tween(menuBtn, {BackgroundTransparency = 0.3, BackgroundColor3 = THEME.Glass}, 0.3)
		mGrad.Enabled = false
		mStroke.Transparency = 0.8
	end
end
menuBtn.MouseButton1Click:Connect(toggleMenu)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.M or input.KeyCode == Enum.KeyCode.Tab then toggleMenu() end
end)

-- Toggle Shop Logic
local function toggleShop(forceOpen)
        if forceOpen ~= nil then isShopOpen = forceOpen else isShopOpen = not isShopOpen end

        if isShopOpen then
                shopOverlay.Visible = true
                shopOverlay.Active = true
                shopOverlay.BackgroundTransparency = 1
                tween(shopFrame, {Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        else
                tween(shopFrame, {Position = UDim2.new(0.5, 0, 1.5, 0)}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.In)
                task.delay(0.5, function()
                        if not isShopOpen then
                                shopOverlay.Visible = false
                                shopOverlay.Active = false
                        end
                end)
        end
end
shopCloseBtn.MouseButton1Click:Connect(function() toggleShop(false) end)

-- =========================================================
-- SELL-ANYWHERE MENU ICON (HIDDEN UNLESS PASS OR !pass sell)
-- =========================================================

local hasSellPass = false

local menuSellBtn = nil
local menuSellLbl = nil

local function updateMenuSellBtn()
	-- Only exists when hasSellPass is true
	if not hasSellPass then
		if menuSellBtn then
			menuSellBtn:Destroy()
			menuSellBtn = nil
			menuSellLbl = nil
		end
		return
	end

	if hasSellPass and not menuSellBtn then
		local btn, _, _, lbl = createGlassButton(menuSidebar, "SELL ALL", UDim2.new(0.9, 0, 0, 40))
		menuSellBtn = btn
		menuSellLbl = lbl

		menuSellBtn.LayoutOrder = 99
		menuSellBtn.BackgroundColor3 = THEME.AccentGreen
		menuSellLbl.TextSize = 18

		menuSellBtn.MouseButton1Click:Connect(function()
			SellAllEvent:FireServer()
			if menuSellLbl then
				menuSellLbl.Text = "SOLD!"
				task.wait(1)
				if menuSellLbl then
					menuSellLbl.Text = "SELL ALL"
				end
			end
		end)
	end
end

local function checkPass()
	-- If ForceSellAnywhere attribute exists (true/false), it overrides the real pass
	local override = player:GetAttribute("ForceSellAnywhere")
	if override ~= nil then
		hasSellPass = (override == true)
		updateMenuSellBtn()
		return
	end

	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, SELL_ANYWHERE_PASS_ID)
	end)

	hasSellPass = (ok and owns) or false
	updateMenuSellBtn()
end

task.spawn(checkPass)

player:GetAttributeChangedSignal("ForceSellAnywhere"):Connect(function()
	checkPass()
end)

-- Dev chat toggle: "!pass sell"
player.Chatted:Connect(function(msg)
	msg = string.lower(tostring(msg or ""))
	if msg == "!pass sell" or msg == "!pass sellanywhere" then
		if isDevPlayer() then
			local cur = player:GetAttribute("ForceSellAnywhere")
			-- Toggle strictly between true/false (so you can enable OR disable)
			if cur == true then
				player:SetAttribute("ForceSellAnywhere", false)
			else
				player:SetAttribute("ForceSellAnywhere", true)
			end
		end
	end
end)

-- Shop Proximity Loop
task.spawn(function()
	while true do
		task.wait(0.5)

		if ShopCenter then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local dist = (hrp.Position - ShopCenter.Position).Magnitude
                                if dist <= SELL_RADIUS and not isShopOpen then
                                        toggleShop(true)
                                elseif dist > SHOP_HIDE_RADIUS and isShopOpen then
                                        toggleShop(false)
                                end
			end
		end
	end
end)

-- Responsive Scaling
local function updateScale()
	local vp = Workspace.CurrentCamera.ViewportSize
	local base = 1080
	local factor = math.clamp(vp.Y / base, 0.7, 1.2)
	menuScale.Scale = factor
	shopScale.Scale = factor
end
Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
updateScale()

switchMenuTab("Inventory")
switchShopTab("Sell")
