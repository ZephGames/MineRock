-- ServerScriptService.DevCommands
-- Dev-only chat commands: !coins, !fly, !unfly / !stopfly
-- Added: pass testing toggles (simulated, NOT real purchases)
--   !pass hold        -> toggles Hold-to-Mine ON/OFF (player attribute ForceHoldToMine)
--   !pass sell        -> toggles Sell-Anywhere ON/OFF (player attribute ForceSellAnywhere)
--   !pass off         -> turns both forced pass flags OFF
--   !pass status      -> prints current forced flags

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local DevFlyToggleEvent = Remotes:WaitForChild("DevFlyToggle") -- RemoteEvent

-- ?? Dev-only: your numeric UserId
local DEV_USER_IDS = {
	[2527826821] = true, -- Zach / Zephrynix_RBX
	[1409730737] = true,
}

-- Track who is currently flying (server-side toggle)
local devFlying = {}

local function getOrCreateLeaderstats(player)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	return ls
end

local function getOrCreateCoins(player)
	local ls = getOrCreateLeaderstats(player)
	local coins = ls:FindFirstChild("Coins")
	if not coins then
		coins = Instance.new("IntValue")
		coins.Name = "Coins"
		coins.Value = 0
		coins.Parent = ls
	end
	return coins
end

local function setForcedPass(player, attrName, newValue)
	player:SetAttribute(attrName, newValue == true)
	print(string.format("DevCommands: %s set %s = %s",
		player.Name, attrName, tostring(newValue == true)))
end

local function toggleForcedPass(player, attrName)
	local cur = player:GetAttribute(attrName) == true
	local newValue = not cur
	player:SetAttribute(attrName, newValue)
	print(string.format("DevCommands: %s toggled %s = %s",
		player.Name, attrName, tostring(newValue)))
end

local function printPassStatus(player)
	local hold = player:GetAttribute("ForceHoldToMine") == true
	local sell = player:GetAttribute("ForceSellAnywhere") == true
	print(string.format("DevCommands: %s pass status -> HoldToMine=%s, SellAnywhere=%s",
		player.Name, tostring(hold), tostring(sell)))
end

local function handleDevChat(player, message)
	-- only your accounts can use these
	if not DEV_USER_IDS[player.UserId] then
		return
	end

	local lower = string.lower(message or "")

	-- ==== !coins AMOUNT ====
	local amountStr = lower:match("^!coins%s+(-?%d+)$")
	if amountStr then
		local amount = tonumber(amountStr)
		if amount then
			local coins = getOrCreateCoins(player)
			coins.Value += amount
			print(string.format("DevCommands: gave %d coins to %s (now %d)",
				amount, player.Name, coins.Value))
		end
		return
	end

	-- ==== !fly (toggle) ====
	if lower == "!fly" then
		local currentlyFlying = devFlying[player] == true
		local newState = not currentlyFlying
		devFlying[player] = newState

		DevFlyToggleEvent:FireClient(player, newState)

		print(string.format("DevCommands: %s flying for %s",
			newState and "ENABLED" or "DISABLED",
			player.Name))

		return
	end

	-- ==== !unfly / !stopfly (force off) ====
	if lower == "!unfly" or lower == "!stopfly" then
		devFlying[player] = false
		DevFlyToggleEvent:FireClient(player, false)
		print(string.format("DevCommands: forced fly OFF for %s", player.Name))
		return
	end

	-- ==== !pass commands (simulated ownership) ====
	-- !pass hold     -> toggles ForceHoldToMine
	-- !pass sell     -> toggles ForceSellAnywhere
	-- !pass off      -> disables both
	-- !pass status   -> prints status
	if lower == "!pass hold" then
		toggleForcedPass(player, "ForceHoldToMine")
		return
	end

	if lower == "!pass sell" then
		toggleForcedPass(player, "ForceSellAnywhere")
		return
	end

	if lower == "!pass off" then
		setForcedPass(player, "ForceHoldToMine", false)
		setForcedPass(player, "ForceSellAnywhere", false)
		printPassStatus(player)
		return
	end

	if lower == "!pass status" then
		printPassStatus(player)
		return
	end
end

Players.PlayerAdded:Connect(function(player)
	player.Chatted:Connect(function(message)
		handleDevChat(player, message)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	devFlying[player] = nil
end)
