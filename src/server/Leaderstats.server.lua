-- ServerScriptService/Leaderstats
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- Toggle saving (turn OFF if you haven't enabled API Services yet)
local USE_DATASTORE = false
local STORE_NAME = "MiningGame_PlayerData_v1"
local Store = DataStoreService:GetDataStore(STORE_NAME)

local DEFAULTS = {
	Coins = 0,
	Rebirths = 0,
	TotalMined = 0,
}

local function makeValue(className, name, parent, value)
	local v = Instance.new(className)
	v.Name = name
	v.Value = value
	v.Parent = parent
	return v
end

local function ensureValue(className, name, parent, value)
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA(className) then
		existing.Value = value
		return existing
	end
	if existing then
		existing:Destroy()
	end
	return makeValue(className, name, parent, value)
end

local function loadData(player)
	if not USE_DATASTORE then
		return table.clone(DEFAULTS)
	end

	local key = "u_" .. player.UserId
	local data
	local ok, err = pcall(function()
		data = Store:GetAsync(key)
	end)

	if not ok or type(data) ~= "table" then
		return table.clone(DEFAULTS)
	end

	-- Fill missing keys with defaults
	for k, v in pairs(DEFAULTS) do
		if data[k] == nil then
			data[k] = v
		end
	end

	return data
end

local function saveData(player)
	if not USE_DATASTORE then return end

	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats then return end

	local coins = leaderstats:FindFirstChild("Coins")
	local rebirths = leaderstats:FindFirstChild("Rebirths")
	local totalMined = leaderstats:FindFirstChild("TotalMined")

	local data = {
		Coins = coins and coins.Value or DEFAULTS.Coins,
		Rebirths = rebirths and rebirths.Value or DEFAULTS.Rebirths,
		TotalMined = totalMined and totalMined.Value or DEFAULTS.TotalMined,
	}

	local key = "u_" .. player.UserId
	pcall(function()
		Store:SetAsync(key, data)
	end)
end

Players.PlayerAdded:Connect(function(player)
	local data = loadData(player)

	-- Leaderstats (shows on leaderboard)
	local leaderstats = player:FindFirstChild("leaderstats")
	if not leaderstats or not leaderstats:IsA("Folder") then
		if leaderstats then
			leaderstats:Destroy()
		end
		leaderstats = Instance.new("Folder")
		leaderstats.Name = "leaderstats"
		leaderstats.Parent = player
	end

	ensureValue("IntValue", "Coins", leaderstats, data.Coins)
	ensureValue("IntValue", "Rebirths", leaderstats, data.Rebirths) -- keep even if you don’t use it yet
	ensureValue("IntValue", "TotalMined", leaderstats, data.TotalMined)

	-- Quest values (NOT in leaderboard)
	makeValue("StringValue", "ActiveQuest", player, "")
	makeValue("IntValue", "QuestProgress", player, 0)

	-- Useful for later boosts/rebirths (not required yet)
	makeValue("NumberValue", "CoinMultiplier", player, 1)
end)

Players.PlayerRemoving:Connect(function(player)
	saveData(player)
end)

game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		saveData(player)
	end
end)
