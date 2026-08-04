--[[
    BuildAnimator Patterns
    ──────────────────────
    Reusable animation pattern presets. Each pattern is a table of config
    overrides that can be passed to BuildAnimator.configure() or used as
    the `pattern` argument to BuildAnimator:play().

    Usage:
        local Patterns = require(path.to.Patterns)
        BuildAnimator:play(parts, Patterns.rise)
        -- or combine:
        BuildAnimator:play(parts, Patterns.scaleIn)
]]

local Patterns = {}

--[[
    Rise — parts emerge from below, sliding upward into place.
    Best for: structures rising from the ground, underground builds.
]]
Patterns.rise = {
    ANIMATION_STYLE = "rise",
    RISE_HEIGHT = 8,
    PART_TWEEN_TIME = 0.35,
    SIZE_EASING_STYLE = Enum.EasingStyle.Back,
    SIZE_EASING_DIRECTION = Enum.EasingDirection.Out,
    TRANS_EASING_STYLE = Enum.EasingStyle.Quad,
    TRANS_EASING_DIRECTION = Enum.EasingDirection.Out,
    STAGGER_DELAY = 0.08,
    LANDING_PARTICLE_COUNT = 10,
}

--[[
    Fade — parts smoothly fade and scale in without movement.
    Best for: ghostly/appearing structures, UI-like reveals.
]]
Patterns.fade = {
    ANIMATION_STYLE = "scale",
    PART_TWEEN_TIME = 0.28,
    SIZE_EASING_STYLE = Enum.EasingStyle.Quad,
    SIZE_EASING_DIRECTION = Enum.EasingDirection.Out,
    TRANS_EASING_STYLE = Enum.EasingStyle.Quad,
    TRANS_EASING_DIRECTION = Enum.EasingDirection.Out,
    STAGGER_DELAY = 0.06,
    LANDING_PARTICLE_COUNT = 4,
    LANDING_PARTICLE_LIFETIME = 0.25,
}

--[[
    Scale-In — parts pop in with a bouncy Back ease. The classic.
    Best for: general construction, playful builds, quick reveals.
]]
Patterns.scaleIn = {
    ANIMATION_STYLE = "scale",
    PART_TWEEN_TIME = 0.30,
    SIZE_EASING_STYLE = Enum.EasingStyle.Back,
    SIZE_EASING_DIRECTION = Enum.EasingDirection.Out,
    TRANS_EASING_STYLE = Enum.EasingStyle.Quad,
    TRANS_EASING_DIRECTION = Enum.EasingDirection.Out,
    STAGGER_DELAY = 0.07,
    LANDING_PARTICLE_COUNT = 8,
}

--[[
    Drop — parts fall from above and settle with a Bounce ease.
    Best for: construction from crane/sky, dramatic entrances.
]]
Patterns.drop = {
    ANIMATION_STYLE = "drop",
    DROP_HEIGHT = 12,
    PART_TWEEN_TIME = 0.35,
    DROP_EASING_STYLE = Enum.EasingStyle.Bounce,
    DROP_EASING_DIRECTION = Enum.EasingDirection.Out,
    SIZE_EASING_STYLE = Enum.EasingStyle.Back,
    SIZE_EASING_DIRECTION = Enum.EasingDirection.Out,
    STAGGER_DELAY = 0.09,
    LANDING_PARTICLE_COUNT = 12,
}

--[[
    Cascade — parts ripple outward from center with elastic easing.
    Best for: radial structures, domes, decorative patterns.
]]
Patterns.cascade = {
    ANIMATION_STYLE = "cascade",
    PART_TWEEN_TIME = 0.38,
    CASCADE_EASING_STYLE = Enum.EasingStyle.Elastic,
    CASCADE_EASING_DIRECTION = Enum.EasingDirection.Out,
    SIZE_EASING_STYLE = Enum.EasingStyle.Elastic,
    SIZE_EASING_DIRECTION = Enum.EasingDirection.Out,
    STAGGER_DELAY = 0.05,
    LANDING_PARTICLE_COUNT = 6,
}

--[[
    Material-Shift — parts fade through a material color transition.
    Best for: magical/transformation effects, remodeling.
]]
Patterns.materialShift = {
    ANIMATION_STYLE = "scale",
    PART_TWEEN_TIME = 0.42,
    SIZE_EASING_STYLE = Enum.EasingStyle.Sine,
    SIZE_EASING_DIRECTION = Enum.EasingDirection.InOut,
    TRANS_EASING_STYLE = Enum.EasingStyle.Sine,
    TRANS_EASING_DIRECTION = Enum.EasingDirection.InOut,
    STAGGER_DELAY = 0.10,
    LANDING_PARTICLE_COUNT = 14,
    LANDING_PARTICLE_LIFETIME = 0.5,
    LANDING_PARTICLE_SPEED = 5,
}

--[[
    Weather — parts arrive with dust/spray particle bursts.
    Best for: outdoor construction, rainy/sandy environments.
]]
Patterns.weather = {
    ANIMATION_STYLE = "weather",
    PART_TWEEN_TIME = 0.34,
    SIZE_EASING_STYLE = Enum.EasingStyle.Back,
    SIZE_EASING_DIRECTION = Enum.EasingDirection.Out,
    STAGGER_DELAY = 0.08,
    LANDING_PARTICLE_COUNT = 8,
    WEATHER_DUST_COUNT = 18,
    WEATHER_DUST_LIFETIME = 0.8,
}

--[[
    Get a pattern by name, or nil if not found.

    @param name string -- pattern key ("rise", "fade", "drop", etc.)
    @return table? -- pattern config or nil
]]
function Patterns.get(name: string)
    return Patterns[name]
end

--[[
    List all available pattern names.

    @return { string } -- sorted list of pattern keys
]]
function Patterns.list(): { string }
    local names = {}
    for key in pairs(Patterns) do
        if type(key) == "string" and type(Patterns[key]) == "table" then
            table.insert(names, key)
        end
    end
    table.sort(names)
    return names
end

--[[
    Merge a pattern with overrides. Returns a new table.

    @param patternName string -- base pattern name
    @param overrides table? -- additional config overrides
    @return table -- merged pattern
]]
function Patterns.extend(patternName: string, overrides: { [string]: any }?): { [string]: any }
    local base = Patterns[patternName]
    if not base then
        error(("Patterns: unknown pattern '%s'"):format(patternName), 2)
    end
    local result = {}
    for key, value in pairs(base) do
        result[key] = value
    end
    if overrides then
        for key, value in pairs(overrides) do
            result[key] = value
        end
    end
    return result
end

return Patterns
