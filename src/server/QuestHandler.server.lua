local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("RojoShared")
local QuestConfig = require(Shared:WaitForChild("QuestConfig"))

local function ensureQuestValues(player)
	local active = player:FindFirstChild("ActiveQuest")
	if not active then
		active = Instance.new("StringValue")
		active.Name = "ActiveQuest"
		active.Value = ""
		active.Parent = player
	end

	local progress = player:FindFirstChild("QuestProgress")
	if not progress then
		progress = Instance.new("IntValue")
		progress.Name = "QuestProgress"
		progress.Value = 0
		progress.Parent = player
	end

	return active, progress
end

local function assignRandomQuest(player)
	local active, progress = ensureQuestValues(player)
	local quest = QuestConfig[math.random(#QuestConfig)]
	active.Value = quest.Id
	progress.Value = 0
end

Players.PlayerAdded:Connect(function(player)
	ensureQuestValues(player)

	player.CharacterAdded:Connect(function()
		task.wait(1)
		assignRandomQuest(player)
	end)
end)

local function updateQuest(player, questType, amount, oreType)
	local active, progress = ensureQuestValues(player)
	local activeQuestId = active.Value
	if activeQuestId == "" then return end

	for _, quest in ipairs(QuestConfig) do
		if quest.Id == activeQuestId then
			if quest.Type ~= questType then return end
			if quest.Type == "MineSpecific" and quest.OreType ~= oreType then return end

			progress.Value += amount

			if progress.Value >= quest.Target then
				local leaderstats = player:FindFirstChild("leaderstats")
				local coins = leaderstats and leaderstats:FindFirstChild("Coins")
				if coins then
					coins.Value += (quest.RewardCoins or 0)
				end

				task.wait(0.5)
				assignRandomQuest(player)
			end
			return
		end
	end
end

_G.UpdateQuest = updateQuest
