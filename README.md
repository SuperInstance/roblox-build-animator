# BuildAnimator

**Cinematic staggered construction animations for Roblox.**

Parts don't pop — they arrive in work order. Each part fades, scales, drops, or rises into place with material-appropriate sound and particle bursts, staggered so a 20-part build streams in over ~1.5s like a time-lapse construction sequence.

## Quick Start

```lua
local BuildAnimator = require(ReplicatedStorage.BuildAnimator)
local Patterns = require(ReplicatedStorage.BuildAnimator.Patterns)

-- Create some parts in workspace
local parts = { wall1, wall2, floor1, roof1 }

-- Animate them!
BuildAnimator:play(parts)

-- Or use a pattern preset
BuildAnimator:play(parts, Patterns.drop)

-- With a completion callback
BuildAnimator:play(parts, Patterns.rise, nil, function()
    print("Construction complete!")
end)
```

## Installation

### With Rojo

1. Clone this repo into your project as a submodule or copy the `src/` folder.
2. Add to your `default.project.json`:

```json
{
  "ReplicatedStorage": {
    "BuildAnimator": {
      "$path": "path/to/roblox-build-animator/src"
    }
  }
}
```

3. `rojo serve` and sync into Studio.

### Manual

1. Copy the contents of `src/init.lua` into a ModuleScript named `BuildAnimator` in ReplicatedStorage.
2. Copy `src/Patterns.lua` into a ModuleScript named `Patterns` inside `BuildAnimator`.

## API Reference

### `BuildAnimator:play(parts, pattern?, center?, onComplete?)`

The primary entry point. Animates an array of parts with staggered timing.

| Parameter | Type | Description |
|-----------|------|-------------|
| `parts` | `{ BasePart }` | Array of parts already in workspace |
| `pattern` | `table?` | Pattern preset (from `Patterns`) or config overrides |
| `center` | `Vector3?` | Build center for sort/burst (auto-calculated if omitted) |
| `onComplete` | `function?` | Callback fired when the last part lands |

```lua
-- Basic
BuildAnimator:play(parts)

-- With pattern
BuildAnimator:play(parts, Patterns.cascade)

-- With inline config overrides
BuildAnimator:play(parts, { ANIMATION_STYLE = "rise", RISE_HEIGHT = 12 })
```

### `BuildAnimator:playInTime(parts, bpm, center?, onComplete?)`

Same as `play()` but derives the stagger from a BPM (musical timing). A 32nd-note grid is used: at 120 BPM, parts land every ~62ms; at 90 BPM, every ~83ms.

```lua
BuildAnimator:playInTime(parts, 120)
```

### `BuildAnimator.animatePart(part, targetTransparency?, style?)`

Animate a single part. Useful for one-off reveals outside of a batch.

### `BuildAnimator.burst(position, color, duration?)`

Fire a particle burst at a world position.

### `BuildAnimator.playPlacementSound(material, position)`

Play a material-appropriate placement sound at a position.

### `BuildAnimator.configure(overrides)`

Permanently override config values.

```lua
BuildAnimator.configure({
    PART_TWEEN_TIME = 0.5,
    MAX_CONCURRENT_ANIMATIONS = 50,
    ANIMATION_STYLE = "scale",
})
```

### `BuildAnimator.resetConfig()`

Reset all config to defaults.

### `BuildAnimator.getConfig()`

Get a copy of the current configuration.

### `BuildAnimator.getStagger(bpm)`

Calculate per-part stagger from BPM. Returns seconds.

### `BuildAnimator.clearQueue()`

Cancel all pending queued animations (does not affect in-flight ones). Returns the number cancelled.

### `BuildAnimator.getStats()`

```lua
local stats = BuildAnimator.getStats()
-- { active = 12, queued = 3, maxConcurrent = 30 }
```

## Events

BuildAnimator emits events through `BindableEvent` connections:

### `BuildAnimator.OnComplete`

Fires when a batch animation completes (last part lands + completion burst).

```lua
BuildAnimator.OnComplete.Event:Connect(function(data)
    print("Build complete at", data.centerPosition)
end)
```

### `BuildAnimator.OnPartRevealed`

Fires for each part as it finishes animating.

```lua
BuildAnimator.OnPartRevealed.Event:Connect(function(part)
    print("Part revealed:", part.Name)
end)
```

## Animation Styles

| Style | Description | Best For |
|-------|-------------|----------|
| `"scale"` | Parts grow in place with Back ease | General construction, playful builds |
| `"drop"` | Parts fall from above with Bounce ease | Crane/sky construction, dramatic |
| `"rise"` | Parts emerge from below | Underground/rising structures |
| `"cascade"` | Parts ripple outward with Elastic ease | Radial structures, domes |
| `"weather"` | Scale-in with dust/spray particle bursts | Outdoor/sandy/rainy environments |

## Pattern Presets

Pre-built configs in `Patterns.lua`. Pass them as the second argument to `play()`:

```lua
local Patterns = require(ReplicatedStorage.BuildAnimator.Patterns)

BuildAnimator:play(parts, Patterns.rise)
BuildAnimator:play(parts, Patterns.scaleIn)
BuildAnimator:play(parts, Patterns.materialShift)
```

| Pattern | Style | Character |
|---------|-------|-----------|
| `Patterns.rise` | rise | Emerges from below, smooth |
| `Patterns.fade` | scale (Quad) | Gentle, ghostly |
| `Patterns.scaleIn` | scale (Back) | Bouncy classic |
| `Patterns.drop` | drop (Bounce) | Weighty, dramatic |
| `Patterns.cascade` | cascade (Elastic) | Ripple wave from center |
| `Patterns.materialShift` | scale (Sine InOut) | Slow, magical |
| `Patterns.weather` | weather | Dusty outdoor construction |

### Pattern API

```lua
-- Get a pattern by name
local p = Patterns.get("drop")

-- List all pattern names
print(Patterns.list())  -- {"cascade", "drop", "fade", ...}

-- Extend a pattern with overrides
local custom = Patterns.extend("drop", { DROP_HEIGHT = 20, STAGGER_DELAY = 0.12 })
BuildAnimator:play(parts, custom)
```

## Spatial Ordering

Parts are sorted for cinematic build order before animation:

| Mode | Description |
|------|-------------|
| `"height_then_distance"` | Foundation up, then center-out (default, most architectural) |
| `"distance"` | Center-out wave |
| `"none"` | Preserve input order |

Set via config:

```lua
BuildAnimator.configure({ BATCH_SORT_MODE = "distance" })
```

Or per-call via pattern override:

```lua
BuildAnimator:play(parts, { BATCH_SORT_MODE = "none" })
```

## Material Sounds

Parts automatically play a sound based on their `Material` property:

| Material Family | Sound | Pitch Range |
|-----------------|-------|-------------|
| Stone (Brick, Concrete, Rock, etc.) | Low thud | 0.76–0.85 |
| Wood (Wood, WoodPlanks, Bamboo) | Woody knock | 1.00–1.10 |
| Metal (Metal, DiamondPlate, Foil) | Metallic clang | 1.15–1.40 |
| Glass (Glass, Ice, ForceField) | Crystal tap | 1.45–1.60 |
| Neon | Soft chime | ~1.50 |

Each playback has ±0.1 random pitch variation for natural variety.

## Customization

### All Config Options

```lua
BuildAnimator.configure({
    -- Tween timing
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

    -- Cascade
    CASCADE_EASING_STYLE = Enum.EasingStyle.Elastic,
    CASCADE_EASING_DIRECTION = Enum.EasingDirection.Out,

    -- Stagger timing
    STAGGER_DELAY = 0.08,

    -- Performance
    MAX_CONCURRENT_ANIMATIONS = 30,

    -- Particles
    LANDING_PARTICLE_COUNT = 8,
    LANDING_PARTICLE_LIFETIME = 0.35,
    LANDING_PARTICLE_SPEED = 4,
    LANDING_PARTICLE_SPREAD = 0.15,
    LANDING_PARTICLE_SIZE = 0.08,

    -- Weather particles
    WEATHER_DUST_COUNT = 14,
    WEATHER_DUST_LIFETIME = 0.7,
    WEATHER_DUST_SPEED = 2.5,
    WEATHER_DUST_SIZE = 0.18,
    WEATHER_DUST_SPREAD = 0.3,

    -- Completion burst
    COMPLETION_PARTICLE_COUNT = 28,
    COMPLETION_PARTICLE_LIFETIME = 0.9,
    COMPLETION_PARTICLE_SPEED = 8,
    COMPLETION_PARTICLE_SIZE = 0.12,

    -- Spatial ordering
    BATCH_SORT_MODE = "height_then_distance",
})
```

## Concurrency

At most `MAX_CONCURRENT_ANIMATIONS` (default 30) parts animate simultaneously. Excess parts are queued and pumped as slots free up. Use `getStats()` to monitor:

```lua
local stats = BuildAnimator.getStats()
print(string.format("Active: %d / Queued: %d / Max: %d",
    stats.active, stats.queued, stats.maxConcurrent))
```

## Server-Safe

All effects (TweenService, ParticleEmitter, Sound, Debris) work on the server. No client-side or LocalScript required. The module is designed for server-side construction animation.

## License

MIT — see [LICENSE](LICENSE).
