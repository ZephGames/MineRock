local QuestConfig = {
        {
                Id = "MineRocks",
                Text = "Mine 12 rocks",
                Type = "MineCount",
                Target = 12,
                RewardCoins = 250,
        },

        {
                Id = "EarnCoins",
                Text = "Earn 4,000 coins",
                Type = "EarnCoins",
                Target = 4000,
                RewardCoins = 1200,
        },

        {
                Id = "MineGold",
                Text = "Mine 5 gold ores",
                Type = "MineSpecific",
                OreType = "Gold",
                Target = 5,
                RewardCoins = 1700,
        },
}

return QuestConfig
