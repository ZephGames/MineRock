-- ReplicatedStorage.OreConfig
local OreConfig = {
	Stone = {
		MaxHealth   = 40,
		RespawnTime = 4,
		Yield       = 2,   -- items dropped by a normal-sized rock
		Value       = 1,   -- coins per item when sold
		TemplateName = "Stone",
		DisplayName = "Stone",
		Rarity      = "Common",
		ImageId     = "rbxassetid://112830302539553",
	},
	Bronze = {
		MaxHealth   = 70,
		RespawnTime = 5,
		Yield       = 2,
		Value       = 2,
		TemplateName = "Bronze",
		DisplayName = "Bronze",
		Rarity      = "Common",
		ImageId     = "rbxassetid://108051546667743",
	},
	Silver = {
		MaxHealth   = 90,
		RespawnTime = 6,
		Yield       = 2,
		Value       = 4,
		TemplateName = "Silver",
		DisplayName = "Silver",
		Rarity      = "Uncommon",
		ImageId     = "rbxassetid://105523487536907",
	},
	Gold = {
		MaxHealth   = 110,
		RespawnTime = 8,
		Yield       = 2,
		Value       = 7,
		TemplateName = "Gold",
		DisplayName = "Gold",
		Rarity      = "Rare",
		ImageId     = "rbxassetid://88603367728270",
	},
	Platinum = {
		MaxHealth   = 130,
		RespawnTime = 10,
		Yield       = 1,
		Value       = 12,
		TemplateName = "Platinum",
		DisplayName = "Platinum",
		Rarity      = "Rare",
		ImageId     = "rbxassetid://110413868675300",
	},
	Emerald = {
		MaxHealth   = 140,
		RespawnTime = 11,
		Yield       = 1,
		Value       = 15,
		TemplateName = "Emerald",
		DisplayName = "Emerald",
		Rarity      = "Epic",
		ImageId     = "rbxassetid://96508201495154",
	},
	Ruby = {
		MaxHealth   = 150,
		RespawnTime = 12,
		Yield       = 1,
		Value       = 18,
		TemplateName = "Ruby",
		DisplayName = "Ruby",
		Rarity      = "Epic",
		ImageId     = "rbxassetid://83185262217794",
	},
	Diamond = {
		MaxHealth   = 160,
		RespawnTime = 13,
		Yield       = 1,
		Value       = 22,
		TemplateName = "Diamond",
		DisplayName = "Diamond",
		Rarity      = "Epic",
		ImageId     = "rbxassetid://113713580064667",
	},
	Obsidian = {
		MaxHealth   = 220,
		RespawnTime = 18,
		Yield       = 1,
		Value       = 30,
		TemplateName = "Obsidian",
		DisplayName = "Obsidian",
		Rarity      = "Legendary",
		ImageId     = "rbxassetid://74571360257862",
	},
}

-- Spawn chance weights (higher = more common)
OreConfig.SpawnWeights = {
	Stone    = 40,
	Bronze   = 25,
	Silver   = 15,
	Gold     = 8,
	Platinum = 5,
	Emerald  = 3,
	Ruby     = 3,
	Diamond  = 2,
	Obsidian = 1,
}

-- Rarity colors (used for labels + inventory/shop)
OreConfig.RarityColors = {
	Common    = Color3.fromRGB(180, 180, 180),
	Uncommon  = Color3.fromRGB(80, 200, 120),
	Rare      = Color3.fromRGB(65, 105, 225),
	Epic      = Color3.fromRGB(163, 53, 238),
	Legendary = Color3.fromRGB(255, 140, 0),
}

return OreConfig
