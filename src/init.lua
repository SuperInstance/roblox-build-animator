--[[
    BuildAnimator
    ─────────────
    Cinematic staggered construction animation for Roblox.

    Parts don't pop — they arrive in work order. Each part fades, scales,
    drops, or rises into place with material-appropriate sound and particle
    bursts, staggered so a 20-part build streams in over ~1.5s like a
    time-lapse construction sequence.

    Framework-agnostic: no dependencies on any specific game framework.
    Accepts a configuration table, emits events via BindableEvent.

    ─────────────────────────────────────────────
    QUICK START
    ─────────────────────────────────────────────
        local BuildAnimator = require(path.to.BuildAnimator)
        local parts = { -- array of BasePart already in workspace }

        -- Simple: use defaults
        BuildAnimator:play(parts)

        -- With a pattern preset
        local Patterns = require(path.to.Patterns)
        BuildAnimator:play(parts, Patterns.drop)

        -- With custom center and callback
        BuildAnimator:play(parts, nil, centerPos, function()
            print("Construction complete!")
        end)

    ─────────────────────────────────────────────
    EVENTS
    ─────────────────────────────────────────────
    BuildAnimator emits events through a BindableEvent:

        BuildAnimator.OnComplete -- fires when a batch finishes
        BuildAnimator.OnPartRevealed -- fires for each part

    Connect like:
        BuildAnimator.OnComplete.Event:Connect(function(parts)
            print("All " .. #parts .. " parts revealed!")
        end)
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

----------------------------------------------------------------
-- MODULE SETUP
----------------------------------------------------------------

local BuildAnimator = {}
BuildAnimator.__index = BuildAnimator

-- Events (BindableEvent-backed)
local _completeEvent = Instance.new("BindableEvent")
local _partRevealedEvent = Instance.new("BindableEvent")
BuildAnimator.OnComplete = _completeEvent.Event
BuildAnimator.OnPartRevealed = _partRevealedEvent.Event

----------------------------------------------------------------
-- DEFAULT CONFIGURATION
----------------------------------------------------------------

local DEFAULT_CONFIG = {
    -- Per-part fade/scale tween
    PART_TWEEN_TIME = 0.32,
    SIZE_EASING_STYLE = Enum.EasingStyle.Back,
    SIZE_EASING_DIRECTION = Enum.EasingDirection.Out,
    TRANS_EASING_STYLE = Enum.EasingStyle.Quad,
    TRANS_EASING_DIRECTION = Enum.EasingDirection.Out,

    -- Animation style: "scale" | "drop" | "rise" | "cascade" | "weather"
    ANIMATION_STYLE = "drop",

    -- Drop trajectory
    DROP_HEIGHT = 10,
    DROP_EASING_STYLE = Enum.EasingStyle.Bounce,
    DROP_EASING_DIRECTION = Enum.EasingDirection.Out,

    -- Rise trajectory
    RISE_HEIGHT = 8,

    -- Cascade (elastic wave)
    CASCADE_EASING_STYLE = Enum.EasingStyle.Elastic,
    CASCADE_EASING_DIRECTION = Enum.EasingDirection.Out,

    -- Staggered streaming
    STAGGER_DELAY = 0.08,

    -- Performance: cap concurrent in-flight animations
    MAX_CONCURRENT_ANIMATIONS = 30,

    -- Particle burst (per-part landing)
    LANDING_PARTICLE_COUNT = 8,
    LANDING_PARTICLE_LIFETIME = 0.35,
    LANDING_PARTICLE_SPEED = 4,
    LANDING_PARTICLE_SPREAD = 0.15,
    LANDING_PARTICLE_SIZE = 0.08,

    -- Weather dust/spray
    WEATHER_DUST_COUNT = 14,
    WEATHER_DUST_LIFETIME = 0.7,
    WEATHER_DUST_SPEED = 2.5,
    WEATHER_DUST_SIZE = 0.18,
    WEATHER_DUST_SPREAD = 0.3,

    -- Completion burst (last part)
    COMPLETION_PARTICLE_COUNT = 28,
    COMPLETION_PARTICLE_LIFETIME = 0.9,
    COMPLETION_PARTICLE_SPEED = 8,
    COMPLETION_PARTICLE_SIZE = 0.12,

    -- Spatial ordering: "height_then_distance" | "distance" | "none"
    BATCH_SORT_MODE = "height_then_distance",
}

-- Active config (starts as a copy of defaults)
local CONFIG = {}
for key, value in pairs(DEFAULT_CONFIG) do
    CONFIG[key] = value
end

----------------------------------------------------------------
-- SOUND IDS — per material family
----------------------------------------------------------------

local SOUND_IDS = {
    THUD = "rbxassetid://314428418",
    WOOD_KNOCK = "rbxassetid://9120149793",
    METAL_CLANG = "rbxassetid://8685257501",
    CHIME = "rbxassetid://9116245410",
    CRYSTAL_TAP = "rbxassetid://18269528686",
    SETTLE = "rbxassetid://314428418",
}

----------------------------------------------------------------
-- MATERIAL CLASSIFICATION
----------------------------------------------------------------

local STONE_MATERIALS = {
    [Enum.Material.Slate] = true, [Enum.Material.Concrete] = true,
    [Enum.Material.Brick] = true, [Enum.Material.Cobblestone] = true,
    [Enum.Material.Rock] = true, [Enum.Material.Sand] = true,
    [Enum.Material.Marble] = true, [Enum.Material.Granite] = true,
    [Enum.Material.Asphalt] = true, [Enum.Material.Basalt] = true,
    [Enum.Material.CrackedLava] = true, [Enum.Material.Ground] = true,
    [Enum.Material.Mud] = true, [Enum.Material.LeafyGrass] = true,
}

local WOOD_MATERIALS = {
    [Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true,
    [Enum.Material.Bamboo] = true,
}

local METAL_MATERIALS = {
    [Enum.Material.Metal] = true, [Enum.Material.DiamondPlate] = true,
    [Enum.Material.Foil] = true, [Enum.Material.CorrodedMetal] = true,
    [Enum.Material.AluminumNitride] = true,
}

local GLASS_MATERIALS = {
    [Enum.Material.Glass] = true, [Enum.Material.Ice] = true,
    [Enum.Material.ForceField] = true,
}

local NEON_MATERIALS = {
    [Enum.Material.Neon] = true,
}

local MATERIAL_PITCHES = {
    [Enum.Material.Slate] = 0.80, [Enum.Material.Concrete] = 0.80,
    [Enum.Material.Brick] = 0.82, [Enum.Material.Cobblestone] = 0.78,
    [Enum.Material.Rock] = 0.80, [Enum.Material.Sand] = 0.85,
    [Enum.Material.Marble] = 0.82, [Enum.Material.Granite] = 0.78,
    [Enum.Material.Asphalt] = 0.80, [Enum.Material.Basalt] = 0.76,
    [Enum.Material.Wood] = 1.00, [Enum.Material.WoodPlanks] = 1.05,
    [Enum.Material.Bamboo] = 1.10, [Enum.Material.Metal] = 1.30,
    [Enum.Material.DiamondPlate] = 1.35, [Enum.Material.Foil] = 1.40,
    [Enum.Material.CorrodedMetal] = 1.15, [Enum.Material.Neon] = 1.50,
    [Enum.Material.Glass] = 1.55, [Enum.Material.Ice] = 1.45,
    [Enum.Material.ForceField] = 1.60,
}

local DEFAULT_PITCH = 0.90

----------------------------------------------------------------
-- CONCURRENCY TRACKING
----------------------------------------------------------------

local activeAnimationCount = 0
local pendingQueue = {}

local function acquireSlot(callback)
    if activeAnimationCount < CONFIG.MAX_CONCURRENT_ANIMATIONS then
        activeAnimationCount += 1
        callback()
    else
        table.insert(pendingQueue, callback)
    end
end

local function releaseSlot()
    activeAnimationCount = math.max(0, activeAnimationCount - 1)
    if #pendingQueue > 0 and activeAnimationCount < CONFIG.MAX_CONCURRENT_ANIMATIONS then
        local next_cb = table.remove(pendingQueue, 1)
        activeAnimationCount += 1
        next_cb()
    end
end

----------------------------------------------------------------
-- INTERNAL HELPERS
----------------------------------------------------------------

local function getPitchForMaterial(material)
    local base = MATERIAL_PITCHES[material] or DEFAULT_PITCH
    local variation = (math.random() - 0.5) * 0.2
    return math.max(0.5, base + variation)
end

local function getSoundIdForMaterial(material)
    if NEON_MATERIALS[material] then return SOUND_IDS.CHIME end
    if GLASS_MATERIALS[material] then return SOUND_IDS.CRYSTAL_TAP end
    if METAL_MATERIALS[material] then return SOUND_IDS.METAL_CLANG end
    if WOOD_MATERIALS[material] then return SOUND_IDS.WOOD_KNOCK end
    return SOUND_IDS.THUD
end

local function calculateBounds(parts)
    local function getPartSize(p)
        return p.Size
    end

    local minVec = parts[1].Position
    local maxVec = parts[1].Position
    for i = 2, #parts do
        local p = parts[i]
        minVec = Vector3.new(
            math.min(minVec.X, p.Position.X),
            math.min(minVec.Y, p.Position.Y),
            math.min(minVec.Z, p.Position.Z)
        )
        maxVec = Vector3.new(
            math.max(maxVec.X, p.Position.X),
            math.max(maxVec.Y, p.Position.Y),
            math.max(maxVec.Z, p.Position.Z)
        )
    end
    for _, p in ipairs(parts) do
        local half = getPartSize(p) * 0.5
        minVec = Vector3.new(
            math.min(minVec.X, p.Position.X - half.X),
            math.min(minVec.Y, p.Position.Y - half.Y),
            math.min(minVec.Z, p.Position.Z - half.Z)
        )
        maxVec = Vector3.new(
            math.max(maxVec.X, p.Position.X + half.X),
            math.max(maxVec.Y, p.Position.Y + half.Y),
            math.max(maxVec.Z, p.Position.Z + half.Z)
        )
    end
    local center = (minVec + maxVec) * 0.5
    local size = maxVec - minVec
    return minVec, maxVec, center, size
end

local function sortPartsSpatially(parts, center, mode)
    local sortMode = mode or CONFIG.BATCH_SORT_MODE
    if sortMode == "none" then return parts end

    local sorted = table.clone(parts)
    if sortMode == "distance" then
        table.sort(sorted, function(a, b)
            return (a.Position - center).Magnitude < (b.Position - center).Magnitude
        end)
    else
        table.sort(sorted, function(a, b)
            local dy = a.Position.Y - b.Position.Y
            if math.abs(dy) > 0.1 then
                return dy < 0
            end
            local ah = Vector3.new(a.Position.X, 0, a.Position.Z)
            local bh = Vector3.new(b.Position.X, 0, b.Position.Z)
            local ch = Vector3.new(center.X, 0, center.Z)
            return (ah - ch).Magnitude < (bh - ch).Magnitude
        end)
    end
    return sorted
end

local function createParticleBurst(position, color, count, lifetime, speed, size)
    local ok, err = pcall(function()
        local carrier = Instance.new("Part")
        carrier.Name = "BACarrier"
        carrier.Size = Vector3.new(0.1, 0.1, 0.1)
        carrier.Position = position
        carrier.Transparency = 1
        carrier.CanCollide = false
        carrier.CanQuery = false
        carrier.Anchored = true
        carrier.Parent = workspace

        local attachment = Instance.new("Attachment")
        attachment.Parent = carrier

        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "BAEmitter"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(color)
        emitter.Size = NumberSequence.new(size)
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Lifetime = NumberRange.new(lifetime * 0.5, lifetime)
        emitter.Speed = NumberRange.new(
            speed * (1 - CONFIG.LANDING_PARTICLE_SPREAD),
            speed * (1 + CONFIG.LANDING_PARTICLE_SPREAD)
        )
        emitter.SpreadAngle = Vector2.new(45, 45)
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.Rate = 0
        emitter.EmitCount = count
        emitter.Parent = attachment

        emitter:Emit(count)
        Debris:AddItem(carrier, lifetime + 0.5)
    end)

    if not ok then
        warn(("[BuildAnimator] particle burst failed: %s"):format(tostring(err)))
    end
end

local function createWeatherBurst(position, color)
    local ok, err = pcall(function()
        local carrier = Instance.new("Part")
        carrier.Name = "BAWeather"
        carrier.Size = Vector3.new(0.1, 0.1, 0.1)
        carrier.Position = position
        carrier.Transparency = 1
        carrier.CanCollide = false
        carrier.CanQuery = false
        carrier.Anchored = true
        carrier.Parent = workspace

        local attachment = Instance.new("Attachment")
        attachment.Parent = carrier

        local dustH, dustS, dustV = color:ToHSV()
        local dustColor = Color3.fromHSV(dustH, dustS * 0.4, dustV * 0.7)

        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "BAWeatherEmitter"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(dustColor)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, CONFIG.WEATHER_DUST_SIZE * 0.5),
            NumberSequenceKeypoint.new(1, CONFIG.WEATHER_DUST_SIZE * 1.5),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0.3),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Lifetime = NumberRange.new(
            CONFIG.WEATHER_DUST_LIFETIME * 0.5,
            CONFIG.WEATHER_DUST_LIFETIME
        )
        emitter.Speed = NumberRange.new(
            CONFIG.WEATHER_DUST_SPEED * (1 - CONFIG.WEATHER_DUST_SPREAD),
            CONFIG.WEATHER_DUST_SPEED * (1 + CONFIG.WEATHER_DUST_SPREAD)
        )
        emitter.SpreadAngle = Vector2.new(60, 60)
        emitter.Rotation = NumberRange.new(0, 360)
        emitter.Rate = 0
        emitter.EmitCount = CONFIG.WEATHER_DUST_COUNT
        emitter.Parent = attachment

        emitter:Emit(CONFIG.WEATHER_DUST_COUNT)
        Debris:AddItem(carrier, CONFIG.WEATHER_DUST_LIFETIME + 0.5)
    end)

    if not ok then
        warn(("[BuildAnimator] weather burst failed: %s"):format(tostring(err)))
    end
end

----------------------------------------------------------------
-- CORE ANIMATION
----------------------------------------------------------------

--[[
    Animate a single part into view.

    @param part BasePart -- must already be parented to workspace
    @param targetTransparency number? -- final transparency (defaults to current)
    @param style string? -- override animation style for this part
]]
function BuildAnimator.animatePart(part, targetTransparency, style)
    if not part or typeof(part) ~= "Instance" or not part:IsA("BasePart") then
        warn("[BuildAnimator] animatePart: expected a BasePart, got " .. tostring(part))
        return
    end

    local targetSize = part.Size
    local targetTrans = targetTransparency or part.Transparency
    local partColor = part.Color
    local partMaterial = part.Material
    local landingPos = part.Position
    local animStyle = style or CONFIG.ANIMATION_STYLE

    acquireSlot(function()
        part.Transparency = 1
        part.Size = Vector3.new(0.1, 0.1, 0.1)

        local positionTween = nil
        if animStyle == "drop" then
            local startPos = landingPos + Vector3.new(0, CONFIG.DROP_HEIGHT, 0)
            part.CFrame = CFrame.new(startPos) * (part.CFrame - part.CFrame.Position)
        elseif animStyle == "rise" then
            local startPos = landingPos + Vector3.new(0, -CONFIG.RISE_HEIGHT, 0)
            part.CFrame = CFrame.new(startPos) * (part.CFrame - part.CFrame.Position)
        end

        local completed = false

        local sizeEasing = CONFIG.SIZE_EASING_STYLE
        local sizeEasingDir = CONFIG.SIZE_EASING_DIRECTION
        if animStyle == "cascade" then
            sizeEasing = CONFIG.CASCADE_EASING_STYLE
            sizeEasingDir = CONFIG.CASCADE_EASING_DIRECTION
        end

        local sizeTween = TweenService:Create(part, TweenInfo.new(
            CONFIG.PART_TWEEN_TIME, sizeEasing, sizeEasingDir
        ), { Size = targetSize })

        local transTween = TweenService:Create(part, TweenInfo.new(
            CONFIG.PART_TWEEN_TIME,
            CONFIG.TRANS_EASING_STYLE, CONFIG.TRANS_EASING_DIRECTION
        ), { Transparency = targetTrans })

        if animStyle == "drop" then
            positionTween = TweenService:Create(part, TweenInfo.new(
                CONFIG.PART_TWEEN_TIME * 1.1,
                CONFIG.DROP_EASING_STYLE, CONFIG.DROP_EASING_DIRECTION
            ), { Position = landingPos })
        elseif animStyle == "rise" then
            positionTween = TweenService:Create(part, TweenInfo.new(
                CONFIG.PART_TWEEN_TIME * 1.1,
                Enum.EasingStyle.Quad, Enum.EasingDirection.Out
            ), { Position = landingPos })
        end

        sizeTween.Completed:Connect(function(playbackState)
            if completed then return end
            completed = true
            releaseSlot()

            if playbackState == Enum.PlaybackState.Completed then
                pcall(function()
                    part.CFrame = CFrame.new(landingPos) * (part.CFrame - part.CFrame.Position)
                    part.Size = targetSize
                    part.Transparency = targetTrans
                end)

                createParticleBurst(
                    landingPos, partColor,
                    CONFIG.LANDING_PARTICLE_COUNT,
                    CONFIG.LANDING_PARTICLE_LIFETIME,
                    CONFIG.LANDING_PARTICLE_SPEED,
                    CONFIG.LANDING_PARTICLE_SIZE
                )

                BuildAnimator.playPlacementSound(partMaterial, landingPos)

                if animStyle == "weather" then
                    createWeatherBurst(landingPos, partColor)
                end

                _partRevealedEvent:Fire(part)
            end
        end)

        task.delay(CONFIG.PART_TWEEN_TIME + 0.5, function()
            if not completed then
                completed = true
                releaseSlot()
                pcall(function()
                    if part and part.Parent then
                        part.CFrame = CFrame.new(landingPos) * (part.CFrame - part.CFrame.Position)
                        part.Size = targetSize
                        part.Transparency = targetTrans
                    end
                end)
            end
        end)

        local ok1 = pcall(function() sizeTween:Play() end)
        local ok2 = pcall(function() transTween:Play() end)
        if positionTween then
            pcall(function() positionTween:Play() end)
        end

        if not ok1 or not ok2 then
            if not completed then
                completed = true
                releaseSlot()
                pcall(function()
                    part.CFrame = CFrame.new(landingPos) * (part.CFrame - part.CFrame.Position)
                    part.Size = targetSize
                    part.Transparency = targetTrans
                end)
            end
        end
    end)
end

--[[
    Animate the final part in a batch and fire the completion burst.

    @param part BasePart -- the last part
    @param centerPosition Vector3 -- build center for completion burst
    @param style string? -- animation style override
]]
function BuildAnimator._animatePartWithCompletion(part, centerPosition, style)
    if not part or not part:IsA("BasePart") then return end

    local targetSize = part.Size
    local targetTrans = part.Transparency
    local partColor = part.Color
    local partMaterial = part.Material
    local landingPos = part.Position
    local animStyle = style or CONFIG.ANIMATION_STYLE

    acquireSlot(function()
        part.Transparency = 1
        part.Size = Vector3.new(0.1, 0.1, 0.1)

        local positionTween = nil
        if animStyle == "drop" then
            local startPos = landingPos + Vector3.new(0, CONFIG.DROP_HEIGHT, 0)
            part.CFrame = CFrame.new(startPos) * (part.CFrame - part.CFrame.Position)
            positionTween = TweenService:Create(part, TweenInfo.new(
                CONFIG.PART_TWEEN_TIME * 1.1,
                CONFIG.DROP_EASING_STYLE, CONFIG.DROP_EASING_DIRECTION
            ), { Position = landingPos })
        elseif animStyle == "rise" then
            local startPos = landingPos + Vector3.new(0, -CONFIG.RISE_HEIGHT, 0)
            part.CFrame = CFrame.new(startPos) * (part.CFrame - part.CFrame.Position)
            positionTween = TweenService:Create(part, TweenInfo.new(
                CONFIG.PART_TWEEN_TIME * 1.1,
                Enum.EasingStyle.Quad, Enum.EasingDirection.Out
            ), { Position = landingPos })
        end

        local completed = false

        local sizeEasing = CONFIG.SIZE_EASING_STYLE
        local sizeEasingDir = CONFIG.SIZE_EASING_DIRECTION
        if animStyle == "cascade" then
            sizeEasing = CONFIG.CASCADE_EASING_STYLE
            sizeEasingDir = CONFIG.CASCADE_EASING_DIRECTION
        end

        local sizeTween = TweenService:Create(part, TweenInfo.new(
            CONFIG.PART_TWEEN_TIME, sizeEasing, sizeEasingDir
        ), { Size = targetSize })

        local transTween = TweenService:Create(part, TweenInfo.new(
            CONFIG.PART_TWEEN_TIME,
            CONFIG.TRANS_EASING_STYLE, CONFIG.TRANS_EASING_DIRECTION
        ), { Transparency = targetTrans })

        sizeTween.Completed:Connect(function(playbackState)
            if completed then return end
            completed = true
            releaseSlot()

            if playbackState == Enum.PlaybackState.Completed then
                pcall(function()
                    part.CFrame = CFrame.new(landingPos) * (part.CFrame - part.CFrame.Position)
                    part.Size = targetSize
                    part.Transparency = targetTrans
                end)

                createParticleBurst(
                    landingPos, partColor,
                    CONFIG.LANDING_PARTICLE_COUNT,
                    CONFIG.LANDING_PARTICLE_LIFETIME,
                    CONFIG.LANDING_PARTICLE_SPEED,
                    CONFIG.LANDING_PARTICLE_SIZE
                )

                BuildAnimator.playPlacementSound(partMaterial, landingPos)

                if animStyle == "weather" then
                    createWeatherBurst(landingPos, partColor)
                end

                -- Completion burst
                task.wait(0.05)

                local completionColors = {
                    Color3.fromRGB(255, 220, 100),
                    Color3.fromRGB(100, 200, 255),
                    Color3.fromRGB(255, 150, 200),
                    Color3.fromRGB(150, 255, 150),
                    Color3.fromRGB(255, 255, 255),
                }

                local perColor = math.floor(CONFIG.COMPLETION_PARTICLE_COUNT / #completionColors)
                for _, burstColor in ipairs(completionColors) do
                    createParticleBurst(
                        centerPosition, burstColor, perColor,
                        CONFIG.COMPLETION_PARTICLE_LIFETIME,
                        CONFIG.COMPLETION_PARTICLE_SPEED,
                        CONFIG.COMPLETION_PARTICLE_SIZE
                    )
                end

                local settleSound = Instance.new("Sound")
                settleSound.SoundId = SOUND_IDS.SETTLE
                settleSound.Volume = 0.6
                settleSound.PlaybackSpeed = 0.55
                settleSound.Parent = workspace
                settleSound:Play()
                Debris:AddItem(settleSound, 3)

                _partRevealedEvent:Fire(part)
                _completeEvent:Fire({ centerPosition = centerPosition })
            end
        end)

        task.delay(CONFIG.PART_TWEEN_TIME + 0.5, function()
            if not completed then
                completed = true
                releaseSlot()
                pcall(function()
                    if part and part.Parent then
                        part.CFrame = CFrame.new(landingPos) * (part.CFrame - part.CFrame.Position)
                        part.Size = targetSize
                        part.Transparency = targetTrans
                    end
                end)
            end
        end)

        local ok1 = pcall(function() sizeTween:Play() end)
        local ok2 = pcall(function() transTween:Play() end)
        if positionTween then
            pcall(function() positionTween:Play() end)
        end

        if not ok1 or not ok2 then
            if not completed then
                completed = true
                releaseSlot()
                pcall(function()
                    part.CFrame = CFrame.new(landingPos) * (part.CFrame - part.CFrame.Position)
                    part.Size = targetSize
                    part.Transparency = targetTrans
                end)
            end
        end
    end)
end

----------------------------------------------------------------
-- PUBLIC API
----------------------------------------------------------------

--[[
    Play a staggered construction animation on a set of parts.

    This is the primary entry point. Pass your parts and optionally a
    pattern (from Patterns.lua) or config overrides.

    @param parts { BasePart } -- array of parts (already in workspace)
    @param pattern table? -- pattern preset or config overrides
    @param center Vector3? -- build center (auto-calculated if omitted)
    @param onComplete function? -- callback when animation finishes

    Examples:
        BuildAnimator:play(parts)
        BuildAnimator:play(parts, Patterns.rise)
        BuildAnimator:play(parts, { ANIMATION_STYLE = "drop" })
        BuildAnimator:play(parts, nil, center, function() ... end)
]]
function BuildAnimator:play(parts, pattern, center, onComplete)
    if not parts or typeof(parts) ~= "table" or #parts == 0 then
        warn("[BuildAnimator] play: expected a non-empty array of parts")
        return
    end

    -- Validate parts
    for i, p in ipairs(parts) do
        if typeof(p) ~= "Instance" or not p:IsA("BasePart") then
            warn(("[BuildAnimator] play: parts[%d] is not a BasePart"):format(i))
            return
        end
    end

    -- Apply pattern overrides temporarily
    local savedConfig = {}
    if pattern then
        for key, value in pairs(pattern) do
            savedConfig[key] = CONFIG[key]
            CONFIG[key] = value
        end
    end

    -- Compute center
    local _, _, boundsCenter, boundsSize = calculateBounds(parts)
    center = center or boundsCenter

    local animStyle = CONFIG.ANIMATION_STYLE
    local stagger = CONFIG.STAGGER_DELAY

    -- Sort parts cinematically
    local sortedParts
    if animStyle == "cascade" then
        sortedParts = sortPartsSpatially(parts, center, "distance")
    else
        sortedParts = sortPartsSpatially(parts, center, CONFIG.BATCH_SORT_MODE)
    end

    -- Connect completion callback
    local conn
    if onComplete then
        conn = _completeEvent.Event:Connect(function()
            onComplete()
        end)
    end

    -- Cascade: distance-proportional delays
    if animStyle == "cascade" then
        local distances = {}
        local maxDist = 0
        for i, part in ipairs(sortedParts) do
            local d = (part.Position - center).Magnitude
            distances[i] = d
            if d > maxDist then maxDist = d end
        end
        maxDist = math.max(maxDist, 0.01)

        local waveTime = #sortedParts * stagger
        for i, part in ipairs(sortedParts) do
            local delay = (distances[i] / maxDist) * waveTime
            task.delay(delay, function()
                if i == #sortedParts then
                    BuildAnimator._animatePartWithCompletion(part, center, animStyle)
                else
                    BuildAnimator.animatePart(part, nil, animStyle)
                end
            end)
        end
    else
        for i, part in ipairs(sortedParts) do
            local delay = (i - 1) * stagger
            task.delay(delay, function()
                if i == #sortedParts then
                    BuildAnimator._animatePartWithCompletion(part, center, animStyle)
                else
                    BuildAnimator.animatePart(part, nil, animStyle)
                end
            end)
        end
    end

    -- Restore config after a reasonable delay
    if pattern then
        local restoreDelay = (#sortedParts * stagger) + CONFIG.PART_TWEEN_TIME + 1.0
        task.delay(restoreDelay, function()
            for key, value in pairs(savedConfig) do
                CONFIG[key] = value
            end
            if conn then
                conn:Disconnect()
            end
        end)
    elseif conn then
        task.delay((#sortedParts * stagger) + CONFIG.PART_TWEEN_TIME + 1.0, function()
            conn:Disconnect()
        end)
    end
end

--[[
    Emit a quick particle burst at a position.

    @param position Vector3 -- world position
    @param color Color3 -- particle color
    @param duration number? -- override particle lifetime (seconds)
]]
function BuildAnimator.burst(position, color, duration)
    createParticleBurst(
        position, color,
        CONFIG.LANDING_PARTICLE_COUNT,
        duration or CONFIG.LANDING_PARTICLE_LIFETIME,
        CONFIG.LANDING_PARTICLE_SPEED,
        CONFIG.LANDING_PARTICLE_SIZE
    )
end

--[[
    Play a placement sound for a given material at a position.

    @param material Enum.Material -- the part's material
    @param position Vector3 -- where to play the sound
]]
function BuildAnimator.playPlacementSound(material, position)
    local soundId = getSoundIdForMaterial(material)
    local pitch = getPitchForMaterial(material)

    pcall(function()
        local carrier = Instance.new("Part")
        carrier.Name = "BASoundCarrier"
        carrier.Size = Vector3.new(0.1, 0.1, 0.1)
        carrier.Position = position
        carrier.Transparency = 1
        carrier.CanCollide = false
        carrier.CanQuery = false
        carrier.Anchored = true
        carrier.Parent = workspace

        local sound = Instance.new("Sound")
        sound.SoundId = soundId
        sound.Volume = 0.35
        sound.PlaybackSpeed = pitch
        sound.RollOffMaxDistance = 60
        sound.RollOffMinDistance = 10
        sound.RollOffMode = Enum.RollOffMode.InverseTapered
        sound.Parent = carrier
        sound:Play()

        Debris:AddItem(carrier, 3)
    end)
end

----------------------------------------------------------------
-- CONFIGURATION
----------------------------------------------------------------

--[[
    Override CONFIG values at runtime.

    @param overrides table -- key/value pairs to merge into CONFIG
]]
function BuildAnimator.configure(overrides)
    for key, value in pairs(overrides or {}) do
        CONFIG[key] = value
    end
end

--[[
    Reset configuration to defaults.
]]
function BuildAnimator.resetConfig()
    for key, value in pairs(DEFAULT_CONFIG) do
        CONFIG[key] = value
    end
end

--[[
    Get a shallow copy of the current CONFIG.

    @return table
]]
function BuildAnimator.getConfig()
    local copy = {}
    for key, value in pairs(CONFIG) do
        copy[key] = value
    end
    return copy
end

----------------------------------------------------------------
-- MUSICAL TIMING (optional)
----------------------------------------------------------------

--[[
    Calculate per-part stagger from BPM.

    A 32nd note = beat / 8. At 120 BPM: ~62ms. At 90 BPM: ~83ms.

    @param bpm number -- beats per minute
    @return number -- seconds between part reveals
]]
function BuildAnimator.getStagger(bpm)
    if typeof(bpm) ~= "number" or bpm <= 0 then
        return DEFAULT_CONFIG.STAGGER_DELAY
    end
    return 60.0 / (bpm * 8)
end

--[[
    Play a batch with musical timing derived from BPM.

    @param parts { BasePart } -- array of parts
    @param bpm number -- current BPM
    @param center Vector3? -- build center
    @param onComplete function? -- callback
]]
function BuildAnimator:playInTime(parts, bpm, center, onComplete)
    local stagger = BuildAnimator.getStagger(bpm)
    local savedStagger = CONFIG.STAGGER_DELAY
    CONFIG.STAGGER_DELAY = stagger

    BuildAnimator:play(parts, nil, center, onComplete)

    task.delay((#parts * stagger) + CONFIG.PART_TWEEN_TIME + 1.0, function()
        CONFIG.STAGGER_DELAY = savedStagger
    end)
end

----------------------------------------------------------------
-- QUEUE MANAGEMENT
----------------------------------------------------------------

--[[
    Cancel all pending queued animations (does not affect in-flight ones).

    @return number -- number of queued items cancelled
]]
function BuildAnimator.clearQueue()
    local count = #pendingQueue
    table.clear(pendingQueue)
    return count
end

--[[
    Get current animation statistics.

    @return table -- { active = number, queued = number }
]]
function BuildAnimator.getStats()
    return {
        active = activeAnimationCount,
        queued = #pendingQueue,
        maxConcurrent = CONFIG.MAX_CONCURRENT_ANIMATIONS,
    }
end

return BuildAnimator
