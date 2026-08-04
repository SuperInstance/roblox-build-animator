-- examples/tower_build.lua
-- Building a 5-story tower with staggered construction animation.
-- Place in StarterPlayerScripts (LocalScript) or a ServerScript.
--
-- Creates a complete 5-story stone tower (foundation, walls, floors,
-- crenellations) and uses BuildAnimator to reveal it floor-by-floor
-- with a "drop from above" pattern. Each story lands with particles
-- and a material-appropriate impact sound.
--
-- This demonstrates:
--   • Spatial sorting (bottom floor first, then up)
--   • The "drop" animation style with bounce easing
--   • Completion burst on the final part
--   • Per-part sound by material (stone thud)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BuildAnimator = require(ReplicatedStorage:WaitForChild("BuildAnimator"))
local Patterns = require(ReplicatedStorage:WaitForChild("Patterns"))

-- ============================================================
--  Tower specification
-- ============================================================

local TOWER_ORIGIN = Vector3.new(0, 0, -40)  -- base center
local FLOOR_HEIGHT = 6
local WALL_THICKNESS = 1
local TOWER_RADIUS = 8
local NUM_FLOORS = 5

-- ============================================================
--  Build the tower parts (hidden until animated)
-- ============================================================

local allParts = {}

local function createTowerPart(name, size, position, material, color)
    local part = Instance.new("Part")
    part.Name = name
    part.Size = size
    part.Position = position
    part.Material = material
    part.Color = color
    part.Anchored = true
    part.CanCollide = true
    part.Transparency = 0
    part.Parent = workspace
    table.insert(allParts, part)
    return part
end

-- Foundation slab
createTowerPart(
    "Foundation",
    Vector3.new(TOWER_RADIUS * 2 + 2, 2, TOWER_RADIUS * 2 + 2),
    TOWER_ORIGIN + Vector3.new(0, 1, 0),
    Enum.Material.Concrete,
    Color3.fromRGB(100, 95, 90)
)

-- For each floor: 4 walls + a floor slab
for floor = 1, NUM_FLOORS do
    local floorY = TOWER_ORIGIN.Y + 2 + (floor - 1) * FLOOR_HEIGHT
    local floorCenter = Vector3.new(TOWER_ORIGIN.X, floorY + FLOOR_HEIGHT / 2 - 0.5, TOWER_ORIGIN.Z)

    -- Floor slab
    createTowerPart(
        string.format("Floor%d_Slab", floor),
        Vector3.new(TOWER_RADIUS * 2, WALL_THICKNESS, TOWER_RADIUS * 2),
        floorCenter + Vector3.new(0, FLOOR_HEIGHT / 2, 0),
        Enum.Material.WoodPlanks,
        Color3.fromRGB(120, 80, 50)
    )

    -- Four walls (leave a door gap on floor 1)
    local hasDoor = (floor == 1)
    local doorWidth = 3

    for wallIdx = 1, 4 do
        local angle = (wallIdx - 1) * math.pi / 2
        local wallDx = math.cos(angle) * TOWER_RADIUS
        local wallDz = math.sin(angle) * TOWER_RADIUS

        local isFrontWall = (wallIdx == 1)
        local width, wx, wz

        if isFrontWall and hasDoor then
            -- Two segments around the door
            for seg = 1, 2 do
                local segOffset = (seg == 1) and -1 or 1
                local segWidth = TOWER_RADIUS - doorWidth / 2

                local segSize = (wallIdx <= 2)
                    and Vector3.new(segWidth, FLOOR_HEIGHT - 1, WALL_THICKNESS)
                    or Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT - 1, segWidth)

                local segPos = floorCenter + Vector3.new(
                    wallDx * 0.5 + (wallIdx <= 2 and segOffset * (TOWER_RADIUS + doorWidth) / 2 or 0),
                    0,
                    wallDz * 0.5 + (wallIdx > 2 and segOffset * (TOWER_RADIUS + doorWidth) / 2 or 0)
                )

                createTowerPart(
                    string.format("Floor%d_Wall%d_Seg%d", floor, wallIdx, seg),
                    segSize, segPos,
                    Enum.Material.Brick,
                    Color3.fromRGB(130, 110, 90)
                )
            end
        else
            local wallSize = (wallIdx <= 2)
                and Vector3.new(TOWER_RADIUS * 2, FLOOR_HEIGHT - 1, WALL_THICKNESS)
                or Vector3.new(WALL_THICKNESS, FLOOR_HEIGHT - 1, TOWER_RADIUS * 2)

            local wallPos = floorCenter + Vector3.new(wallDx, 0, wallDz)

            createTowerPart(
                string.format("Floor%d_Wall%d", floor, wallIdx),
                wallSize, wallPos,
                Enum.Material.Brick,
                Color3.fromRGB(130, 110, 90)
            )
        end
    end
end

-- Crenellations on top (decorative merlons)
local numMerlons = 12
for i = 1, numMerlons do
    local angle = (i - 1) * (math.pi * 2 / numMerlons)
    local merlonPos = TOWER_ORIGIN + Vector3.new(
        math.cos(angle) * TOWER_RADIUS,
        2 + NUM_FLOORS * FLOOR_HEIGHT + 1,
        math.sin(angle) * TOWER_RADIUS
    )
    createTowerPart(
        string.format("Merlon_%02d", i),
        Vector3.new(1.5, 2, 1.5),
        merlonPos,
        Enum.Material.Slate,
        Color3.fromRGB(90, 85, 80)
    )
end

-- ============================================================
--  Animate the tower rising
-- ============================================================

print(string.format("[Tower Build] %d parts created. Starting animation...", #allParts))

-- Use the "drop" pattern — parts fall from above with bounce easing
-- BuildAnimator's default spatial sort (height_then_distance) ensures
-- bottom floors animate before top floors.
local dropPattern = Patterns.extend("drop", {
    DROP_HEIGHT = 15,         -- dramatic drop distance
    STAGGER_DELAY = 0.06,     -- tight stagger for fluid feel
    PART_TWEEN_TIME = 0.35,
    LANDING_PARTICLE_COUNT = 14,
    COMPLETION_PARTICLE_COUNT = 40,
})

BuildAnimator.OnPartRevealed:Connect(function(part)
    -- Could play per-floor stinger sounds here, update UI, etc.
end)

BuildAnimator.OnComplete:Connect(function(data)
    print("[Tower Build] 🏰 Construction complete!")
    print(string.format("  Center: %s", tostring(data.centerPosition)))

    -- Add a flag on top
    local flag = Instance.new("Part")
    flag.Name = "TowerFlag"
    flag.Size = Vector3.new(0.2, 4, 0.2)
    flag.Position = data.centerPosition + Vector3.new(0, 6, 0)
    flag.Anchored = true
    flag.Material = Enum.Material.Wood
    flag.Color = Color3.fromRGB(60, 40, 30)
    flag.Parent = workspace

    local flagCloth = Instance.new("Part")
    flagCloth.Name = "TowerFlagCloth"
    flagCloth.Size = Vector3.new(2, 1.5, 0.1)
    flagCloth.Position = data.centerPosition + Vector3.new(1, 7.5, 0)
    flagCloth.Anchored = true
    flagCloth.Material = Enum.Material.Fabric
    flagCloth.Color = Color3.fromRGB(200, 50, 50)
    flagCloth.Parent = workspace
end)

-- Play the animation
BuildAnimator:play(allParts, dropPattern, TOWER_ORIGIN)

print("[Tower Build] Animation started — watch it rise!")
