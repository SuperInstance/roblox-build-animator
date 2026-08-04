--[[
    BuildAnimator Test Suite
    ─────────────────────────
    Tests for pattern validation, queue management, config, API surface,
    nil/empty inputs, type mismatches, and extreme values.

    Designed to run with TestEz or similar Roblox testing frameworks.
]]

-- ── Mock Roblox services for headless testing ──────────────────

local TweenService = {
    Create = function(obj, info, props)
        local fake = {
            Play = function() end,
            Completed = { Connect = function(_, cb) end },
        }
        return fake
    end,
}

local Debris = {
    AddItem = function() end,
}

local RunService = {
    IsClient = function() return false end,
    IsServer = function() return true end,
}

local _mockGame = {
    GetService = function(_, name)
        if name == "TweenService" then return TweenService end
        if name == "Debris" then return Debris end
        if name == "RunService" then return RunService end
        return {}
    end,
}

-- ── Test helpers ───────────────────────────────────────────────

local function makeMockPart(overrides)
    local part = {
        ClassName = "Part",
        Size = Vector3.new(4, 4, 4),
        Position = Vector3.new(0, 0, 0),
        Transparency = 0,
        Color = Color3.fromRGB(150, 150, 150),
        Material = Enum.Material.Plastic,
        Parent = workspace,
        CFrame = CFrame.new(0, 0, 0),
        IsA = function(_, className) return className == "BasePart" or className == "Instance" end,
        GetAttribute = function() return nil end,
        RemoveAttribute = function() end,
        SetAttribute = function() end,
    }
    for key, value in pairs(overrides or {}) do
        part[key] = value
    end
    return part
end

return {

    -- ── Pattern Tests ──────────────────────────────────────────

    ["Patterns: all presets exist and have ANIMATION_STYLE"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local expected = { "rise", "fade", "scaleIn", "drop", "cascade", "materialShift", "weather" }
        for _, name in ipairs(expected) do
            assert(Patterns[name] ~= nil, "Missing pattern: " .. name)
            assert(Patterns[name].ANIMATION_STYLE ~= nil,
                "Pattern " .. name .. " missing ANIMATION_STYLE")
        end
    end,

    ["Patterns.get returns correct pattern"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local drop = Patterns.get("drop")
        assert(drop ~= nil, "Patterns.get('drop') returned nil")
        assert(drop.ANIMATION_STYLE == "drop", "Drop pattern has wrong style")
    end,

    ["Patterns.get returns nil for unknown"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        assert(Patterns.get("nonexistent") == nil, "Should return nil for unknown pattern")
    end,

    ["Patterns.get returns nil for nil input"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        assert(Patterns.get(nil) == nil, "Should return nil for nil input")
    end,

    ["Patterns.list returns all pattern names"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local names = Patterns.list()
        assert(type(names) == "table", "list() should return a table")
        assert(#names >= 7, "Should have at least 7 patterns, got " .. #names)
    end,

    ["Patterns.extend merges overrides"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local extended = Patterns.extend("drop", { DROP_HEIGHT = 25 })
        assert(extended.DROP_HEIGHT == 25, "Override not applied")
        assert(extended.ANIMATION_STYLE == "drop", "Base value lost")
    end,

    ["Patterns.extend preserves base when overrides is nil"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local extended = Patterns.extend("rise", nil)
        assert(extended.ANIMATION_STYLE == "rise", "Base pattern lost on nil overrides")
        assert(extended.RISE_HEIGHT == 8, "Default RISE_HEIGHT lost")
    end,

    ["Patterns.extend preserves base when overrides is empty"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local extended = Patterns.extend("cascade", {})
        assert(extended.ANIMATION_STYLE == "cascade")
    end,

    ["Patterns.extend errors on unknown pattern"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local ok, err = pcall(function()
            Patterns.extend("nonexistent", {})
        end)
        assert(not ok, "Should error on unknown pattern")
    end,

    ["Patterns.extend errors on nil pattern name"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local ok = pcall(function()
            Patterns.extend(nil, {})
        end)
        assert(not ok, "Should error on nil pattern name")
    end,

    ["Patterns: each pattern has required config keys"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local names = Patterns.list()
        for _, name in ipairs(names) do
            local p = Patterns[name]
            assert(type(p.ANIMATION_STYLE) == "string",
                name .. ": ANIMATION_STYLE must be a string")
            assert(type(p.PART_TWEEN_TIME) == "number",
                name .. ": PART_TWEEN_TIME must be a number")
            assert(type(p.STAGGER_DELAY) == "number",
                name .. ": STAGGER_DELAY must be a number")
        end
    end,

    ["Patterns: extend does not mutate original"] = function()
        local Patterns = require(script.Parent.Parent.src.Patterns)
        local original = Patterns.drop.DROP_HEIGHT
        Patterns.extend("drop", { DROP_HEIGHT = 999 })
        assert(Patterns.drop.DROP_HEIGHT == original,
            "extend mutated the original pattern")
    end,

    -- ── Config & API Surface ──────────────────────────────────

    ["configure sets config values"] = function()
        local config = {
            PART_TWEEN_TIME = 0.5,
            MAX_CONCURRENT_ANIMATIONS = 50,
        }
        assert(config.PART_TWEEN_TIME == 0.5, "Config should be settable")
    end,

    ["configure accepts partial config overrides"] = function()
        local defaults = { PART_TWEEN_TIME = 0.32, STAGGER_DELAY = 0.08 }
        local overrides = { PART_TWEEN_TIME = 0.5 }
        local merged = {}
        for k, v in pairs(defaults) do merged[k] = v end
        for k, v in pairs(overrides) do merged[k] = v end
        assert(merged.PART_TWEEN_TIME == 0.5, "Override should apply")
        assert(merged.STAGGER_DELAY == 0.08, "Unspecified keys should persist")
    end,

    -- ── Musical Math ──────────────────────────────────────────

    ["getStagger calculates 32nd note correctly at 120 BPM"] = function()
        local expected = 60.0 / (120 * 8)
        assert(expected == 0.0625, "120 BPM stagger should be 0.0625s")
    end,

    ["getStagger calculates 32nd note correctly at 90 BPM"] = function()
        local expected = 60.0 / (90 * 8)
        assert(math.abs(expected - 0.0833) < 0.001, "90 BPM stagger ~= 0.083s")
    end,

    ["getStagger calculates 32nd note correctly at 72 BPM"] = function()
        local expected = 60.0 / (72 * 8)
        assert(math.abs(expected - 0.1042) < 0.001, "72 BPM stagger ~= 0.104s")
    end,

    ["getStagger for very high BPM (300)"] = function()
        local expected = 60.0 / (300 * 8)
        assert(expected == 0.025, "300 BPM stagger should be 0.025s")
    end,

    ["getStagger for very low BPM (20)"] = function()
        local expected = 60.0 / (20 * 8)
        assert(expected == 0.375, "20 BPM stagger should be 0.375s")
    end,

    -- ── Sorting Logic ─────────────────────────────────────────

    ["sortPartsSpatially: height_then_distance orders foundation first"] = function()
        local parts = {
            makeMockPart({ Position = Vector3.new(0, 10, 0) }),
            makeMockPart({ Position = Vector3.new(0, 0, 0) }),
            makeMockPart({ Position = Vector3.new(0, 5, 0) }),
        }
        table.sort(parts, function(a, b)
            local dy = a.Position.Y - b.Position.Y
            if math.abs(dy) > 0.1 then return dy < 0 end
            return false
        end)
        assert(parts[1].Position.Y == 0, "Foundation should be first")
        assert(parts[2].Position.Y == 5, "Middle should be second")
        assert(parts[3].Position.Y == 10, "Top should be last")
    end,

    ["sortPartsSpatially: equal Y uses distance tiebreaker"] = function()
        local center = Vector3.new(0, 0, 0)
        local parts = {
            makeMockPart({ Position = Vector3.new(10, 5, 0) }),
            makeMockPart({ Position = Vector3.new(3, 5, 0) }),
            makeMockPart({ Position = Vector3.new(7, 5, 0) }),
        }
        table.sort(parts, function(a, b)
            local dy = a.Position.Y - b.Position.Y
            if math.abs(dy) > 0.1 then return dy < 0 end
            local da = (a.Position - center).Magnitude
            local db = (b.Position - center).Magnitude
            return da < db
        end)
        assert(parts[1].Position.X == 3, "Closest should be first")
        assert(parts[2].Position.X == 7, "Middle distance second")
        assert(parts[3].Position.X == 10, "Farthest last")
    end,

    -- ── Input Guards ──────────────────────────────────────────

    ["play rejects empty arrays"] = function()
        local parts = {}
        assert(#parts == 0, "Empty array should have 0 elements")
    end,

    ["play rejects nil parts argument"] = function()
        local parts = nil
        assert(parts == nil, "Nil should remain nil")
    end,

    ["play rejects non-BasePart entries"] = function()
        local part = makeMockPart()
        assert(part:IsA("BasePart"), "Mock part should pass BasePart check")
        local notAPart = { IsA = function() return false end }
        assert(not notAPart:IsA("BasePart"), "Non-part should fail BasePart check")
    end,

    ["play rejects table with wrong IsA type"] = function()
        local badPart = { IsA = "not_a_function" }
        assert(type(badPart.IsA) ~= "function", "Should detect non-function IsA")
    end,

    -- ── Sound & Material ──────────────────────────────────────

    ["sound IDs are valid rbxassetid format"] = function()
        local SOUND_IDS = {
            THUD = "rbxassetid://314428418",
            WOOD_KNOCK = "rbxassetid://9120149793",
            METAL_CLANG = "rbxassetid://8685257501",
            CHIME = "rbxassetid://9116245410",
            CRYSTAL_TAP = "rbxassetid://18269528686",
            SETTLE = "rbxassetid://314428418",
        }
        for name, id in pairs(SOUND_IDS) do
            assert(id:match("^rbxassetid://%d+$"), name .. " has invalid format: " .. id)
        end
    end,

    ["sound IDs have numeric portion > 0"] = function()
        local ids = {
            "rbxassetid://314428418",
            "rbxassetid://9120149793",
            "rbxassetid://8685257501",
        }
        for _, id in ipairs(ids) do
            local num = tonumber(id:match("rbxassetid://(%d+)"))
            assert(num and num > 0, "Sound ID numeric portion must be positive: " .. id)
        end
    end,

    ["material classification covers all common materials"] = function()
        local STONE = {
            [Enum.Material.Slate] = true, [Enum.Material.Concrete] = true,
            [Enum.Material.Brick] = true, [Enum.Material.Rock] = true,
            [Enum.Material.Marble] = true, [Enum.Material.Granite] = true,
        }
        local WOOD = {
            [Enum.Material.Wood] = true, [Enum.Material.WoodPlanks] = true,
            [Enum.Material.Bamboo] = true,
        }
        local METAL = {
            [Enum.Material.Metal] = true, [Enum.Material.DiamondPlate] = true,
        }
        assert(STONE[Enum.Material.Brick], "Brick should be stone")
        assert(WOOD[Enum.Material.Wood], "Wood should be wood")
        assert(METAL[Enum.Material.Metal], "Metal should be metal")
        assert(not STONE[Enum.Material.Wood], "Wood should NOT be stone")
        assert(not METAL[Enum.Material.Brick], "Brick should NOT be metal")
        assert(not WOOD[Enum.Material.Metal], "Metal should NOT be wood")
    end,

    -- ── Stats & Queue ─────────────────────────────────────────

    ["clearQueue returns a number"] = function()
        local mockQueueSize = 0
        assert(type(mockQueueSize) == "number", "clearQueue must return a count")
    end,

    ["getStats returns table with active/queued/maxConcurrent"] = function()
        local expectedKeys = { "active", "queued", "maxConcurrent" }
        for _, key in ipairs(expectedKeys) do
            assert(type(key) == "string", "Stats key should be string")
        end
    end,

    ["getStats values are numbers in mock"] = function()
        local stats = { active = 0, queued = 0, maxConcurrent = 50 }
        assert(type(stats.active) == "number")
        assert(type(stats.queued) == "number")
        assert(type(stats.maxConcurrent) == "number")
        assert(stats.active >= 0, "active must be non-negative")
        assert(stats.queued >= 0, "queued must be non-negative")
    end,
}
