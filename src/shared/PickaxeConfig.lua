-- ReplicatedStorage/RojoShared/PickaxeConfig.lua

local PickaxeConfig = {}

-- NOTE: ModelName overrides match your PickaxeModels folder names exactly
-- (e.g., "BloodForge", "TidePiercer") even when Id casing differs.

PickaxeConfig.Tiers = {
    {
        Id = "ForemanSteel",
        DisplayName = "Foreman Steel",
        Damage = 10,
        Cooldown = 0.55,
        CritChance = 0.06,
        CritMultiplier = 1.55,
        Cost = 0,
        Description = "Reliable shop-grade steel. Everyone starts here.",
        Color = Color3.fromRGB(190, 190, 200),
        SizeScale = 1.00,
        GlowBrightness = 0,
        RainbowGlow = false,
        ModelName = "ForemanSteel",
    },
    {
        Id = "EmberGrip",
        DisplayName = "Ember Grip",
        Damage = 14,
        Cooldown = 0.52,
        CritChance = 0.07,
        CritMultiplier = 1.60,
        Cost = 250,
        Description = "Heat-treated head with a grippy core.",
        Color = Color3.fromRGB(255, 110, 40),
        SizeScale = 1.05,
        GlowBrightness = 0.8,
        RainbowGlow = false,
        ModelName = "EmberGrip",
    },
    {
        Id = "CobaltArc",
        DisplayName = "Cobalt Arc",
        Damage = 19,
        Cooldown = 0.49,
        CritChance = 0.08,
        CritMultiplier = 1.70,
        Cost = 700,
        Description = "Sleek cobalt profile for smooth strikes.",
        Color = Color3.fromRGB(70, 120, 255),
        SizeScale = 1.10,
        GlowBrightness = 1.2,
        RainbowGlow = false,
        ModelName = "CobaltArc",
    },
    {
        Id = "Tidepiercer",
        DisplayName = "Tidepiercer",
        Damage = 26,
        Cooldown = 0.46,
        CritChance = 0.10,
        CritMultiplier = 1.80,
        Cost = 2000,
        Description = "Hydro-tempered edge; fast and precise.",
        Color = Color3.fromRGB(60, 200, 200),
        SizeScale = 1.15,
        GlowBrightness = 1.6,
        RainbowGlow = false,
        ModelName = "TidePiercer", -- matches your folder name
    },
    {
        Id = "JungleViper",
        DisplayName = "Jungle Viper",
        Damage = 34,
        Cooldown = 0.43,
        CritChance = 0.12,
        CritMultiplier = 1.90,
        Cost = 5000,
        Description = "Biotech finish with venomous bite.",
        Color = Color3.fromRGB(50, 170, 80),
        SizeScale = 1.20,
        GlowBrightness = 2.0,
        RainbowGlow = false,
        ModelName = "JungleViper",
    },
    {
        Id = "Bloodforge",
        DisplayName = "Bloodforge",
        Damage = 44,
        Cooldown = 0.40,
        CritChance = 0.14,
        CritMultiplier = 2.00,
        Cost = 12000,
        Description = "Redlined mechanisms for brutal impact.",
        Color = Color3.fromRGB(200, 45, 55),
        SizeScale = 1.22,
        GlowBrightness = 2.4,
        RainbowGlow = false,
        ModelName = "BloodForge", -- matches your folder name
    },
    {
        Id = "AetherHalo",
        DisplayName = "Aether Halo",
        Damage = 56,
        Cooldown = 0.37,
        CritChance = 0.15,
        CritMultiplier = 2.10,
        Cost = 30000,
        Description = "Silver-cyan chassis with an aetheric ring.",
        Color = Color3.fromRGB(180, 230, 255),
        SizeScale = 1.25,
        GlowBrightness = 3.0,
        RainbowGlow = false,
        ModelName = "AetherHalo",
    },
    {
        Id = "NightshadePrism",
        DisplayName = "Nightshade Prism",
        Damage = 70,
        Cooldown = 0.35,
        CritChance = 0.16,
        CritMultiplier = 2.20,
        Cost = 80000,
        Description = "Prismatic edges in deep violet shadow.",
        Color = Color3.fromRGB(140, 60, 200),
        SizeScale = 1.28,
        GlowBrightness = 3.4,
        RainbowGlow = false,
        ModelName = "NightshadePrism",
    },
    {
        Id = "VoidReaver",
        DisplayName = "Void Reaver",
        Damage = 88,
        Cooldown = 0.33,
        CritChance = 0.18,
        CritMultiplier = 2.30,
        Cost = 200000,
        Description = "Endgame monster—reaving strikes from the void.",
        Color = Color3.fromRGB(20, 20, 40),
        SizeScale = 1.30,
        GlowBrightness = 4.0,
        RainbowGlow = true,
        ModelName = "VoidReaver",
    },
}

function PickaxeConfig.GetTierCount()
    return #PickaxeConfig.Tiers
end

function PickaxeConfig.GetTier(index)
    return PickaxeConfig.Tiers[index]
end

return PickaxeConfig
