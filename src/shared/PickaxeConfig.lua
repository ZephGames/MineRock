-- ReplicatedStorage/RojoShared/PickaxeConfig.lua
local PickaxeConfig = {}

PickaxeConfig.Tiers = {
  { Id="ForemanSteel",    DisplayName="Foreman Steel",
    Damage=10, Cooldown=0.55, CritChance=0.05, CritMultiplier=1.5, Cost=0,
    Description="Basic workhorse.", Color=Color3.fromRGB(210,210,210),
    SizeScale=1.22, GlowBrightness=0, RainbowGlow=false,
    -- fine-tune spawn-in alignment (optional):
    MountOffset=Vector3.new(0, -0.55, -0.35), MountAngles=Vector3.new(-10,-90,10),
  },
  { Id="EmberGrip",       DisplayName="Ember Grip",
    Damage=14, Cooldown=0.52, CritChance=0.06, CritMultiplier=1.55, Cost=250,
    Description="Heat-forged for steadier swings.",
    Color=Color3.fromRGB(230,120,70), SizeScale=1.24, GlowBrightness=1.0, RainbowGlow=false,
  },
  { Id="CobaltArc",       DisplayName="Cobalt Arc",
    Damage=18, Cooldown=0.49, CritChance=0.08, CritMultiplier=1.65, Cost=750,
    Description="Snappy mid-tier precision.",
    Color=Color3.fromRGB(60,130,200), SizeScale=1.26, GlowBrightness=1.2, RainbowGlow=false,
  },
  { Id="Tidepiercer",     DisplayName="Tidepiercer", ModelName="Tidepiercer",
    Damage=24, Cooldown=0.46, CritChance=0.10, CritMultiplier=1.8, Cost=2000,
    Description="Sea-tempered sweep.",
    Color=Color3.fromRGB(60,165,185), SizeScale=1.28, GlowBrightness=1.5, RainbowGlow=false,
  },
  { Id="JungleViper",     DisplayName="Jungle Viper",
    Damage=31, Cooldown=0.43, CritChance=0.12, CritMultiplier=1.95, Cost=4500,
    Description="Coiled speed and bite.",
    Color=Color3.fromRGB(60,180,90), SizeScale=1.30, GlowBrightness=1.8, RainbowGlow=false,
  },
  { Id="Bloodforge",      DisplayName="Bloodforge", ModelName="Bloodforge",
    Damage=40, Cooldown=0.40, CritChance=0.13, CritMultiplier=2.0, Cost=9500,
    Description="Heavy, ruthless impact.",
    Color=Color3.fromRGB(180,40,40), SizeScale=1.32, GlowBrightness=2.0, RainbowGlow=false,
  },
  { Id="AetherHalo",      DisplayName="Aether Halo",
    Damage=50, Cooldown=0.38, CritChance=0.14, CritMultiplier=2.05, Cost=16000,
    Description="Weightless strikes.",
    Color=Color3.fromRGB(200,230,255), SizeScale=1.34, GlowBrightness=2.5, RainbowGlow=false,
  },
  { Id="NightshadePrism", DisplayName="Nightshade Prism",
    Damage=62, Cooldown=0.36, CritChance=0.15, CritMultiplier=2.1, Cost=23000,
    Description="Shifts with the dark.",
    Color=Color3.fromRGB(110,50,160), SizeScale=1.36, GlowBrightness=3.0, RainbowGlow=false,
  },
  { Id="VoidReaver",      DisplayName="Void Reaver",
    Damage=76, Cooldown=0.34, CritChance=0.16, CritMultiplier=2.15, Cost=30000,
    Description="Endgame power; reality-bending glow.",
    Color=Color3.fromRGB(30,30,55), SizeScale=1.38, GlowBrightness=3.5, RainbowGlow=true,
  },
}

function PickaxeConfig.GetTierCount() return #PickaxeConfig.Tiers end
function PickaxeConfig.GetTier(index) return PickaxeConfig.Tiers[index] end

return PickaxeConfig
