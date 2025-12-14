-- src/shared/RarityFX.lua
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local RarityFX = {}

-- Replace these sound ids later (you can keep them the same for now)
RarityFX.BreakSounds = {
        Default = "rbxassetid://9118826043",
}

RarityFX.HitSoundId = "rbxassetid://9118826043"

local rarityStyles = {
        Default = {
                GlowBrightness = 1,
                GlowRange = 10,
                FillTransparency = 0.4,
                OutlineTransparency = 0.05,
                AuraRate = 6,
                SparkRate = 2,
                HitParticles = 10,
                BreakParticles = 28,
                HitVolume = 0.4,
                BreakVolume = 0.75,
                PitchMin = 0.92,
                PitchMax = 1.05,
        },
        Common = { AuraRate = 4, SparkRate = 2, GlowRange = 8 },
        Uncommon = { AuraRate = 5, SparkRate = 3, GlowBrightness = 1.1 },
        Rare = { AuraRate = 7, SparkRate = 4, GlowBrightness = 1.2, BreakParticles = 32 },
        Epic = { AuraRate = 9, SparkRate = 5, GlowBrightness = 1.3, BreakParticles = 36 },
        Legendary = { AuraRate = 11, SparkRate = 6, GlowBrightness = 1.4, BreakParticles = 40 },
}

local function getPrimary(model: Instance)
        if model:IsA("Model") then
                return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        end
        return nil
end

local function getStyle(rarityName: string, rarityColor: Color3)
        local base = rarityStyles.Default
        local style = rarityStyles[rarityName] or base
        local color = rarityColor or Color3.new(1, 1, 1)

        return {
                GlowBrightness = style.GlowBrightness or base.GlowBrightness,
                GlowRange = style.GlowRange or base.GlowRange,
                FillTransparency = style.FillTransparency or base.FillTransparency,
                OutlineTransparency = style.OutlineTransparency or base.OutlineTransparency,
                AuraRate = style.AuraRate or base.AuraRate,
                SparkRate = style.SparkRate or base.SparkRate,
                HitParticles = style.HitParticles or base.HitParticles,
                BreakParticles = style.BreakParticles or base.BreakParticles,
                HitVolume = style.HitVolume or base.HitVolume,
                BreakVolume = style.BreakVolume or base.BreakVolume,
                PitchMin = style.PitchMin or base.PitchMin,
                PitchMax = style.PitchMax or base.PitchMax,
                Color = color,
        }
end

local function ensureAttachment(primary: BasePart)
        local attachment = primary:FindFirstChild("RarityFXAttachment")
        if not attachment then
                attachment = Instance.new("Attachment")
                attachment.Name = "RarityFXAttachment"
                attachment.Parent = primary
        end
        return attachment
end

local function ensureSound(parent: Instance, name: string, soundId: string, volume: number)
        local sound = parent:FindFirstChild(name)
        if not sound then
                sound = Instance.new("Sound")
                sound.Name = name
                sound.RollOffMode = Enum.RollOffMode.InverseTapered
                sound.RollOffMaxDistance = 80
                sound.RollOffMinDistance = 6
                sound.Volume = volume
                sound.Parent = parent
        end

        sound.SoundId = soundId
        sound.Volume = volume
        return sound
end

local function ensureLight(primary: BasePart, style)
        local light = primary:FindFirstChild("RarityGlow")
        if not light then
                light = Instance.new("PointLight")
                light.Name = "RarityGlow"
                light.Brightness = style.GlowBrightness
                light.Range = style.GlowRange
                light.Enabled = true
                light.Shadows = true
                light.Parent = primary
        end

        light.Brightness = style.GlowBrightness
        light.Range = style.GlowRange
        light.Color = style.Color
        light.Enabled = true
        return light
end

local function ensureHighlight(model: Model, style)
        local highlight = model:FindFirstChild("RarityHighlight")
        if not highlight then
                highlight = Instance.new("Highlight")
                highlight.Name = "RarityHighlight"
                highlight.DepthMode = Enum.HighlightDepthMode.Occluded
                highlight.Adornee = model
                highlight.Parent = model
        end

        highlight.FillColor = style.Color
        highlight.OutlineColor = style.Color:lerp(Color3.new(1, 1, 1), 0.25)
        highlight.FillTransparency = style.FillTransparency
        highlight.OutlineTransparency = style.OutlineTransparency
        highlight.Enabled = true
        return highlight
end

local function ensureParticle(attachment: Attachment, name: string, color: ColorSequence, texture: string, baseRate: number)
        local emitter = attachment:FindFirstChild(name)
        if not emitter then
                emitter = Instance.new("ParticleEmitter")
                emitter.Name = name
                emitter.Speed = NumberRange.new(1, 3)
                emitter.Lifetime = NumberRange.new(0.5, 1.2)
                emitter.SpreadAngle = Vector2.new(35, 35)
                emitter.Rate = baseRate
                emitter.Texture = texture
                emitter.LightInfluence = 0
                emitter.Drag = 1
                emitter.RotSpeed = NumberRange.new(-90, 90)
                emitter.Parent = attachment
        end

        emitter.Color = color
        emitter.Rate = baseRate
        emitter.Texture = texture
        return emitter
end

local function ensureHitEmitter(attachment: Attachment, style)
        local emitter = attachment:FindFirstChild("OreHitEmitter")
        if not emitter then
                emitter = Instance.new("ParticleEmitter")
                emitter.Name = "OreHitEmitter"
                emitter.Rate = 0
                emitter.Speed = NumberRange.new(8, 14)
                emitter.Lifetime = NumberRange.new(0.3, 0.7)
                emitter.SpreadAngle = Vector2.new(30, 30)
                emitter.Texture = "rbxassetid://243660364" -- shard-like spark
                emitter.LightEmission = 0.45
                emitter.Size = NumberSequence.new({
                        NumberSequenceKeypoint.new(0, 0.35),
                        NumberSequenceKeypoint.new(0.4, 0.2),
                        NumberSequenceKeypoint.new(1, 0),
                })
                emitter.Drag = 2
                emitter.Parent = attachment
        end

        emitter.Color = ColorSequence.new(style.Color)
        return emitter
end

local function flashLight(light: PointLight)
        if not light then return end

        local goal = { Brightness = light.Brightness * 1.6 }
        local tween = TweenService:Create(light, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), goal)
        tween:Play()
        Debris:AddItem(tween, 0.3)
end

local function flashHighlight(highlight: Highlight)
        if not highlight then return end

        local tween = TweenService:Create(highlight, TweenInfo.new(0.15, Enum.EasingStyle.Quart, Enum.EasingDirection.Out, 0, true), {
                FillTransparency = math.clamp(highlight.FillTransparency - 0.2, 0, 1),
                OutlineTransparency = math.clamp(highlight.OutlineTransparency - 0.15, 0, 1),
        })
        tween:Play()
        Debris:AddItem(tween, 0.4)
end

local function playPitchShifted(sound: Sound, pitchMin: number, pitchMax: number)
        if not sound then return end
        local playback = math.random() * (pitchMax - pitchMin) + pitchMin
        sound.PlaybackSpeed = playback
        sound:Play()
end

function RarityFX.ApplyToRock(rockModel: Instance, rarityName: string, rarityColor: Color3)
        local primary = getPrimary(rockModel)
        if not primary then return end

        if rockModel:GetAttribute("RarityFXApplied") then
                return
        end
        rockModel:SetAttribute("RarityFXApplied", true)

        local style = getStyle(rarityName, rarityColor or Color3.new(1, 1, 1))

        -- Highlight + glow bring the rock to life
        local highlight = ensureHighlight(rockModel, style)
        local light = ensureLight(primary, style)
        light.Brightness = style.GlowBrightness

        local attachment = ensureAttachment(primary)

        -- Ambient aura (soft dust) and sparkles
        ensureParticle(attachment, "OreAura", ColorSequence.new(style.Color:lerp(Color3.new(1, 1, 1), 0.25)), "rbxassetid://3525524383", style.AuraRate)
        ensureParticle(attachment, "OreSparkle", ColorSequence.new(style.Color), "rbxassetid://2592174290", style.SparkRate)
        ensureHitEmitter(attachment, style)

        -- Break + hit sounds
        ensureSound(primary, "RarityBreakSound", RarityFX.BreakSounds.Default, style.BreakVolume)
        ensureSound(primary, "RarityHitSound", RarityFX.HitSoundId, style.HitVolume)

        -- Quick shimmer on spawn
        flashLight(light)
        flashHighlight(highlight)
end

function RarityFX.PlayHit(rockModel: Instance, rarityName: string)
        local primary = getPrimary(rockModel)
        if not primary then return end

        local light = primary:FindFirstChild("RarityGlow")
        local attachment = primary:FindFirstChild("RarityFXAttachment")
        local highlight = rockModel:FindFirstChild("RarityHighlight")

        local style = getStyle(rarityName or "Default", primary.Color)

        if attachment then
                local emitter = attachment:FindFirstChild("OreHitEmitter")
                if emitter then
                        emitter:Emit(style.HitParticles)
                end
                local spark = attachment:FindFirstChild("OreSparkle")
                if spark then
                        spark:Emit(math.max(2, math.floor(style.HitParticles / 2)))
                end
        end

        flashLight(light)
        flashHighlight(highlight)

        local hitSound = primary:FindFirstChild("RarityHitSound")
        playPitchShifted(hitSound, style.PitchMin, style.PitchMax)
end

function RarityFX.PlayBreak(rockModel: Instance, rarityName: string)
        local primary = getPrimary(rockModel)
        if not primary then return end

        local style = getStyle(rarityName or "Default", primary.Color)
        local attachment = primary:FindFirstChild("RarityFXAttachment")

        if attachment then
                local emitter = attachment:FindFirstChild("OreHitEmitter")
                if emitter then
                        emitter:Emit(style.BreakParticles)
                end
                local aura = attachment:FindFirstChild("OreAura")
                if aura then
                        aura:Emit(math.floor(style.BreakParticles * 0.5))
                end
        end

        local breakSound = primary:FindFirstChild("RarityBreakSound")
        if breakSound then
                        breakSound.Volume = style.BreakVolume
                        playPitchShifted(breakSound, style.PitchMin * 0.95, style.PitchMax * 0.95)
        end

        -- final shimmer
        local highlight = rockModel:FindFirstChild("RarityHighlight")
        flashHighlight(highlight)
end

return RarityFX
