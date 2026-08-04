-- examples/village_spawn.lua
-- Spawning a village of 10 structures with varied animation patterns.
-- Place in StarterPlayerScripts (LocalScript) or a ServerScript.
--
-- Creates a village with different building types:
--   • 3 cottages (wood, "drop" pattern — solid, grounded feel)
--   • 2 market stalls (fabric, "fade" pattern — light, tent-like)
--   • 2 storage sheds (metal, "rise" pattern — emerging from ground)
--   • 1 well (stone, "scaleIn" pattern — classic construction)
--   • 1 signpost (wood, "cascade" pattern — decorative pop)
--   • 1 campfire (neon, "weather" pattern — mystical arrival)
--
-- Each structure uses a different BuildAnimator pattern to give the
-- village visual variety. Structures spawn in waves radiating outward
-- from the village center.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildAnimator = require(ReplicatedStorage:WaitForChild("BuildAnimator"))
local Patterns = require(ReplicatedStorage:WaitForChild("Patterns"))

-- ============================================================
--  Village layout
-- ============================================================

local VILLAGE_CENTER = Vector3.new(50, 0, 20)

-- Structure definitions: { name, parts, pattern, position, delay }
local structures = {}

-- ── Helper: create a simple box building ───────────────────────

local function makeBuilding(name, walls, roof, position, materials)
    local parts = {}

    -- Walls
    for _, w in ipairs(walls) do
        local part = Instance.new("Part")
        part.Name = string.format("%s_%s", name, w.label)
        part.Size = w.size
        part.Position = position + w.offset
        part.Material = materials.wall
        part.Color = materials.wallColor
        part.Anchored = true
        part.Parent = workspace
        table.insert(parts, part)
    end

    -- Roof
    if roof then
        local part = Instance.new("Part")
        part.Name = name .. "_Roof"
        part.Size = roof.size
        part.Position = position + roof.offset
        part.Material = materials.roof or materials.wall
        part.Color = materials.roofColor or materials.wallColor
        part.Anchored = true
        part.Parent = workspace
        table.insert(parts, part)
    end

    return parts
end

-- ── Cottage: 4 walls + peaked roof ─────────────────────────────

local function createCottage(name, position)
    local wallH = 4
    local w = 6  -- width
    local d = 6  -- depth
    return makeBuilding(name, {
        { label = "WallN", size = Vector3.new(w, wallH, 0.5), offset = Vector3.new(0, wallH/2, -d/2) },
        { label = "WallS", size = Vector3.new(w, wallH, 0.5), offset = Vector3.new(0, wallH/2, d/2) },
        { label = "WallE", size = Vector3.new(0.5, wallH, d), offset = Vector3.new(w/2, wallH/2, 0) },
        { label = "WallW", size = Vector3.new(0.5, wallH, d), offset = Vector3.new(-w/2, wallH/2, 0) },
        { label = "Floor", size = Vector3.new(w, 0.5, d), offset = Vector3.new(0, 0.25, 0) },
    }, {
        size = Vector3.new(w + 2, 1, d + 2),
        offset = Vector3.new(0, wallH + 0.5, 0),
    }, position, {
        wall = Enum.Material.WoodPlanks,
        wallColor = Color3.fromRGB(140, 100, 60),
        roof = Enum.Material.Wood,
        roofColor = Color3.fromRGB(100, 60, 30),
    })
end

-- ── Market stall: frame + fabric canopy ────────────────────────

local function createStall(name, position)
    local parts = {}
    local postH = 3.5
    local canopyW = 6
    local canopyD = 4

    -- 4 corner posts
    for _, corner in ipairs({ {1,1}, {1,-1}, {-1,1}, {-1,-1} }) do
        local post = Instance.new("Part")
        post.Name = string.format("%s_Post%d", name, #parts + 1)
        post.Size = Vector3.new(0.3, postH, 0.3)
        post.Position = position + Vector3.new(corner[1] * canopyW/2, postH/2, corner[2] * canopyD/2)
        post.Material = Enum.Material.Wood
        post.Color = Color3.fromRGB(80, 50, 30)
        post.Anchored = true
        post.Parent = workspace
        table.insert(parts, post)
    end

    -- Fabric canopy
    local canopy = Instance.new("Part")
    canopy.Name = name .. "_Canopy"
    canopy.Size = Vector3.new(canopyW + 0.5, 0.2, canopyD + 0.5)
    canopy.Position = position + Vector3.new(0, postH, 0)
    canopy.Material = Enum.Material.Fabric
    canopy.Color = Color3.fromRGB(180, 60, 60)
    canopy.Anchored = true
    canopy.Parent = workspace
    table.insert(parts, canopy)

    return parts
end

-- ── Storage shed: corrugated metal ─────────────────────────────

local function createShed(name, position)
    return makeBuilding(name, {
        { label = "WallN", size = Vector3.new(4, 3, 0.3), offset = Vector3.new(0, 1.5, -2) },
        { label = "WallS", size = Vector3.new(4, 3, 0.3), offset = Vector3.new(0, 1.5, 2) },
        { label = "WallE", size = Vector3.new(0.3, 3, 4), offset = Vector3.new(2, 1.5, 0) },
        { label = "WallW", size = Vector3.new(0.3, 3, 4), offset = Vector3.new(-2, 1.5, 0) },
    }, {
        size = Vector3.new(5, 0.3, 5),
        offset = Vector3.new(0, 3.2, 0),
    }, position, {
        wall = Enum.Material.CorrodedMetal,
        wallColor = Color3.fromRGB(120, 110, 95),
        roof = Enum.Material.DiamondPlate,
        roofColor = Color3.fromRGB(100, 100, 100),
    })
end

-- ── Well: stone circle + wooden frame ──────────────────────────

local function createWell(name, position)
    local parts = {}

    -- Stone ring (8 segments)
    for i = 1, 8 do
        local angle = (i - 1) * math.pi / 4
        local seg = Instance.new("Part")
        seg.Name = string.format("%s_Stone%d", name, i)
        seg.Size = Vector3.new(1, 1.5, 0.8)
        seg.Position = position + Vector3.new(math.cos(angle) * 1.5, 0.75, math.sin(angle) * 1.5)
        seg.Material = Enum.Material.Cobblestone
        seg.Color = Color3.fromRGB(100, 95, 90)
        seg.Anchored = true
        seg.Parent = workspace
        table.insert(parts, seg)
    end

    -- Two support posts + crossbar
    for _, offset in ipairs({ Vector3.new(-1.5, 0, 0), Vector3.new(1.5, 0, 0) }) do
        local post = Instance.new("Part")
        post.Name = name .. "_Post"
        post.Size = Vector3.new(0.3, 4, 0.3)
        post.Position = position + offset + Vector3.new(0, 2, 0)
        post.Material = Enum.Material.Wood
        post.Color = Color3.fromRGB(80, 50, 30)
        post.Anchored = true
        post.Parent = workspace
        table.insert(parts, post)
    end

    local crossbar = Instance.new("Part")
    crossbar.Name = name .. "_Crossbar"
    crossbar.Size = Vector3.new(3.5, 0.3, 0.3)
    crossbar.Position = position + Vector3.new(0, 4, 0)
    crossbar.Material = Enum.Material.Wood
    crossbar.Color = Color3.fromRGB(80, 50, 30)
    crossbar.Anchored = true
    crossbar.Parent = workspace
    table.insert(parts, crossbar)

    return parts
end

-- ── Campfire: stones + neon center ─────────────────────────────

local function createCampfire(name, position)
    local parts = {}

    -- Stone ring
    for i = 1, 6 do
        local angle = (i - 1) * math.pi / 3
        local stone = Instance.new("Part")
        stone.Name = string.format("%s_Stone%d", name, i)
        stone.Size = Vector3.new(0.8, 0.5, 0.8)
        stone.Position = position + Vector3.new(math.cos(angle) * 1, 0.25, math.sin(angle) * 1)
        stone.Material = Enum.Material.Rock
        stone.Color = Color3.fromRGB(70, 65, 60)
        stone.Anchored = true
        stone.Parent = workspace
        table.insert(parts, stone)
    end

    -- Fire core (neon)
    local fire = Instance.new("Part")
    fire.Name = name .. "_Fire"
    fire.Size = Vector3.new(0.8, 1.2, 0.8)
    fire.Position = position + Vector3.new(0, 0.6, 0)
    fire.Material = Enum.Material.Neon
    fire.Color = Color3.fromRGB(255, 120, 30)
    fire.Anchored = true
    fire.Parent = workspace
    table.insert(parts, fire)

    return parts
end

-- ============================================================
--  Build the village
-- ============================================================

local function spawnVillage()
    -- Cottage ring (inner)
    for i = 1, 3 do
        local angle = (i - 1) * (math.pi * 2 / 3) + math.pi / 6
        local pos = VILLAGE_CENTER + Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12)
        local parts = createCottage("Cottage" .. i, pos)
        table.insert(structures, {
            name = "Cottage " .. i,
            parts = parts,
            pattern = Patterns.drop,
            delay = (i - 1) * 0.8,
        })
    end

    -- Market stalls (inner-mid)
    for i = 1, 2 do
        local angle = i * math.pi
        local pos = VILLAGE_CENTER + Vector3.new(math.cos(angle) * 8, 0, math.sin(angle) * 8)
        local parts = createStall("Stall" .. i, pos)
        table.insert(structures, {
            name = "Market Stall " .. i,
            parts = parts,
            pattern = Patterns.fade,
            delay = 2.4 + (i - 1) * 0.6,
        })
    end

    -- Storage sheds (mid ring)
    for i = 1, 2 do
        local pos = VILLAGE_CENTER + Vector3.new(i == 1 and 16 or -16, 0, 8)
        local parts = createShed("Shed" .. i, pos)
        table.insert(structures, {
            name = "Storage Shed " .. i,
            parts = parts,
            pattern = Patterns.rise,
            delay = 3.6 + (i - 1) * 0.6,
        })
    end

    -- Central well
    local wellParts = createWell("Well", VILLAGE_CENTER)
    table.insert(structures, {
        name = "Village Well",
        parts = wellParts,
        pattern = Patterns.scaleIn,
        delay = 0,  -- first thing to appear
    })

    -- Signpost near entrance
    local signParts = {}
    local signPost = Instance.new("Part")
    signPost.Name = "SignPost"
    signPost.Size = Vector3.new(0.2, 4, 0.2)
    signPost.Position = VILLAGE_CENTER + Vector3.new(0, 2, 20)
    signPost.Material = Enum.Material.WoodPlanks
    signPost.Color = Color3.fromRGB(120, 80, 40)
    signPost.Anchored = true
    signPost.Parent = workspace
    table.insert(signParts, signPost)

    local signBoard = Instance.new("Part")
    signBoard.Name = "SignBoard"
    signBoard.Size = Vector3.new(2, 1, 0.1)
    signBoard.Position = VILLAGE_CENTER + Vector3.new(0, 3.5, 20)
    signBoard.Material = Enum.Material.Wood
    signBoard.Color = Color3.fromRGB(140, 100, 60)
    signBoard.Anchored = true
    signBoard.Parent = workspace
    table.insert(signParts, signBoard)

    table.insert(structures, {
        name = "Signpost",
        parts = signParts,
        pattern = Patterns.cascade,
        delay = 5.0,
    })

    -- Campfire (atmospheric)
    local fireParts = createCampfire("Campfire", VILLAGE_CENTER + Vector3.new(5, 0, -5))
    table.insert(structures, {
        name = "Campfire",
        parts = fireParts,
        pattern = Patterns.weather,
        delay = 5.6,
    })

    -- ============================================================
    --  Animate each structure on schedule
    -- ============================================================

    local totalParts = 0
    for _, s in ipairs(structures) do
        totalParts += #s.parts
    end

    print(string.format("[Village Spawn] %d structures, %d total parts. Spawning...",
        #structures, totalParts))

    for _, struct in ipairs(structures) do
        task.delay(struct.delay, function()
            print(string.format("[Village Spawn] Building: %s (%d parts, %s pattern)",
                struct.name, #struct.parts, struct.pattern.ANIMATION_STYLE))

            BuildAnimator:play(struct.parts, struct.pattern)
        end)
    end

    -- Final fanfare
    BuildAnimator.OnComplete:Connect(function(data)
        -- Only fire once for the last structure
    end)

    -- Summary after all structures should be done
    task.delay(8.0, function()
        print("[Village Spawn] 🏘️ Village complete!")
    end)
end

-- Run it
spawnVillage()
