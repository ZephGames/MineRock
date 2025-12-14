-- ReplicatedStorage.PickaxeConfig

local PickaxeConfig = {}

PickaxeConfig.Tiers = {
        {
                Id = "Rusty",
                DisplayName = "Rusty Pickaxe",
                Damage = 8,
                Cooldown = 0.55,
                CritChance = 0.05,
                CritMultiplier = 1.5,
                Cost = 0,
                Description = "Basic pickaxe. Everyone starts here.",
                Color = Color3.fromRGB(200, 200, 200),
                SizeScale = 1.0,
                GlowBrightness = 0,       -- no glow
                RainbowGlow = false,
        },
        {
                Id = "Bronze",
                DisplayName = "Bronze Pickaxe",
                Damage = 12,
                Cooldown = 0.52,
                CritChance = 0.06,
                CritMultiplier = 1.55,
                Cost = 200,
                Description = "Stronger starter that steadies your swings.",
                Color = Color3.fromRGB(205, 127, 50),
                SizeScale = 1.05,
                GlowBrightness = 1,       -- small glow
                RainbowGlow = false,
        },
        {
                Id = "Silver",
                DisplayName = "Silver Pickaxe",
                Damage = 17,
                Cooldown = 0.48,
                CritChance = 0.08,
                CritMultiplier = 1.65,
                Cost = 650,
                Description = "Reliable mid-tier speed and impact.",
                Color = Color3.fromRGB(192, 192, 192),
                SizeScale = 1.1,
                GlowBrightness = 1.5,
                RainbowGlow = false,
        },
        {
                Id = "Gold",
                DisplayName = "Gold Pickaxe",
                Damage = 24,
                Cooldown = 0.44,
                CritChance = 0.10,
                CritMultiplier = 1.8,
                Cost = 1800,
                Description = "Great for serious miners.",
                Color = Color3.fromRGB(255, 215, 0),
                SizeScale = 1.15,
                GlowBrightness = 2,
                RainbowGlow = false,
        },
        {
                Id = "Platinum",
                DisplayName = "Platinum Pickaxe",
                Damage = 32,
                Cooldown = 0.40,
                CritChance = 0.12,
                CritMultiplier = 1.95,
                Cost = 4500,
                Description = "Fast, powerful strikes.",
                Color = Color3.fromRGB(180, 205, 255),
                SizeScale = 1.2,
                GlowBrightness = 2.5,
                RainbowGlow = false,
        },
        {
                Id = "Diamond",
                DisplayName = "Diamond Pickaxe",
                Damage = 42,
                Cooldown = 0.37,
                CritChance = 0.14,
                CritMultiplier = 2.05,
                Cost = 11000,
                Description = "Elite miner gear.",
                Color = Color3.fromRGB(135, 206, 235),
                SizeScale = 1.25,
                GlowBrightness = 3,
                RainbowGlow = false,
        },
        {
                Id = "Obsidian",
                DisplayName = "Obsidian Pickaxe",
                Damage = 55,
                Cooldown = 0.34,
                CritChance = 0.16,
                CritMultiplier = 2.15,
                Cost = 25000,
                Description = "Insane power for late game.",
                Color = Color3.fromRGB(20, 20, 40),
                SizeScale = 1.3,
                GlowBrightness = 3.5,
                RainbowGlow = true,       -- RGB gamer mode
        },
}

function PickaxeConfig.GetTierCount()
        return #PickaxeConfig.Tiers
end

function PickaxeConfig.GetTier(index)
        return PickaxeConfig.Tiers[index]
end

return PickaxeConfig
