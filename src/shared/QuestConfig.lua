local QuestConfig = {
	{
		Id = "MineRocks",
		Text = "Mine 10 rocks",
		Type = "MineCount",
		Target = 10,
		RewardCoins = 500,
	},

	{
		Id = "EarnCoins",
		Text = "Earn 2,000 coins",
		Type = "EarnCoins",
		Target = 2000,
		RewardCoins = 750,
	},

	{
		Id = "MineGold",
		Text = "Mine 3 gold ores",
		Type = "MineSpecific",
		OreType = "Gold",
		Target = 3,
		RewardCoins = 1200,
	},
}

return QuestConfig
