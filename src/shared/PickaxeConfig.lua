-- ReplicatedStorage.PickaxeConfig

local PickaxeConfig = {}

PickaxeConfig.Tiers = {
	{
		Id = "Rusty",
		DisplayName = "Rusty Pickaxe",
		Damage = 10,
		Cooldown = 0.50,
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
		Damage = 14,
		Cooldown = 0.45,
		Cost = 300,
		Description = "Hits harder and a bit faster.",
		Color = Color3.fromRGB(205, 127, 50),
		SizeScale = 1.05,
		GlowBrightness = 1,       -- small glow
		RainbowGlow = false,
	},
	{
		Id = "Silver",
		DisplayName = "Silver Pickaxe",
		Damage = 19,
		Cooldown = 0.40,
		Cost = 900,
		Description = "Solid upgrade over bronze.",
		Color = Color3.fromRGB(192, 192, 192),
		SizeScale = 1.1,
		GlowBrightness = 1.5,
		RainbowGlow = false,
	},
	{
		Id = "Gold",
		DisplayName = "Gold Pickaxe",
		Damage = 25,
		Cooldown = 0.37,
		Cost = 2500,
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
		Cooldown = 0.34,
		Cost = 7500,
		Description = "Fast, powerful strikes.",
		Color = Color3.fromRGB(180, 205, 255),
		SizeScale = 1.2,
		GlowBrightness = 2.5,
		RainbowGlow = false,
	},
	{
		Id = "Diamond",
		DisplayName = "Diamond Pickaxe",
		Damage = 40,
		Cooldown = 0.31,
		Cost = 18000,
		Description = "Elite miner gear.",
		Color = Color3.fromRGB(135, 206, 235),
		SizeScale = 1.25,
		GlowBrightness = 3,
		RainbowGlow = false,
	},
	{
		Id = "Obsidian",
		DisplayName = "Obsidian Pickaxe",
		Damage = 50,
		Cooldown = 0.28,
		Cost = 45000,
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
