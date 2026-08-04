--[[
    BuildAnimator Demo Script
    ──────────────────────────
    Spawns a 5-story tower (25 parts) and animates it with BuildAnimator.
    Place this in ServerScriptService to see it in action.

    Cycles through all patterns every few seconds so you can see each one.
]]

local BuildAnimator = require(script.Parent)
local Patterns = require(script.Parent.Patterns)

local TOWER_HEIGHT = 5
local TOWER_WIDTH = 6
local PART_SIZE = Vector3.new(4, 4, 4)
local SPACING = 4.2
local BUILD_ORIGIN = Vector3.new(0, 0, -20)

local function createTower()
    local parts = {}

    for floor = 1, TOWER_HEIGHT do
        local y = BUILD_ORIGIN.Y + (floor - 1) * SPACING

        -- Four walls per floor
        -- Front wall
        local front = Instance.new("Part")
        front.Size = Vector3.new(TOWER_WIDTH * SPACING, PART_SIZE.Y, PART_SIZE.Z)
        front.Position = Vector3.new(BUILD_ORIGIN.X, y, BUILD_ORIGIN.Z + (TOWER_WIDTH * SPACING / 2))
        front.Anchored = true
        front.Color = Color3.fromRGB(140, 120, 90)
        front.Material = Enum.Material.Brick
        front.Parent = workspace
        table.insert(parts, front)

        -- Back wall
        local back = Instance.new("Part")
        back.Size = Vector3.new(TOWER_WIDTH * SPACING, PART_SIZE.Y, PART_SIZE.Z)
        back.Position = Vector3.new(BUILD_ORIGIN.X, y, BUILD_ORIGIN.Z - (TOWER_WIDTH * SPACING / 2))
        back.Anchored = true
        back.Color = Color3.fromRGB(140, 120, 90)
        back.Material = Enum.Material.Brick
        back.Parent = workspace
        table.insert(parts, back)

        -- Left wall
        local leftWall = Instance.new("Part")
        leftWall.Size = Vector3.new(PART_SIZE.Z, PART_SIZE.Y, TOWER_WIDTH * SPACING)
        leftWall.Position = Vector3.new(BUILD_ORIGIN.X - (TOWER_WIDTH * SPACING / 2), y, BUILD_ORIGIN.Z)
        leftWall.Anchored = true
        leftWall.Color = Color3.fromRGB(140, 120, 90)
        leftWall.Material = Enum.Material.Brick
        leftWall.Parent = workspace
        table.insert(parts, leftWall)

        -- Right wall
        local rightWall = Instance.new("Part")
        rightWall.Size = Vector3.new(PART_SIZE.Z, PART_SIZE.Y, TOWER_WIDTH * SPACING)
        rightWall.Position = Vector3.new(BUILD_ORIGIN.X + (TOWER_WIDTH * SPACING / 2), y, BUILD_ORIGIN.Z)
        rightWall.Anchored = true
        rightWall.Color = Color3.fromRGB(140, 120, 90)
        rightWall.Material = Enum.Material.Brick
        rightWall.Parent = workspace
        table.insert(parts, rightWall)

        -- Floor slab every other level
        if floor % 2 == 1 then
            local slab = Instance.new("Part")
            slab.Size = Vector3.new(TOWER_WIDTH * SPACING, 1, TOWER_WIDTH * SPACING)
            slab.Position = Vector3.new(BUILD_ORIGIN.X, y - 2, BUILD_ORIGIN.Z)
            slab.Anchored = true
            slab.Color = Color3.fromRGB(100, 100, 110)
            slab.Material = Enum.Material.Concrete
            slab.Parent = workspace
            table.insert(parts, slab)
        end
    end

    return parts
end

local function cleanupParts(parts)
    for _, part in ipairs(parts) do
        if part and part.Parent then
            part:Destroy()
        end
    end
end

-- Connect events
BuildAnimator.OnPartRevealed:Connect(function(part)
    -- Each part as it appears
end)

BuildAnimator.OnComplete:Connect(function(data)
    print(("[Demo] Construction complete at %s"):format(tostring(data.centerPosition)))
end)

-- Cycle through patterns
local patternCycle = {
    { name = "scaleIn", config = Patterns.scaleIn },
    { name = "drop", config = Patterns.drop },
    { name = "rise", config = Patterns.rise },
    { name = "cascade", config = Patterns.cascade },
    { name = "fade", config = Patterns.fade },
    { name = "weather", config = Patterns.weather },
}

local cycleIndex = 1

local function runDemo()
    while true do
        local entry = patternCycle[cycleIndex]
        print(("[Demo] Building tower with pattern: %s"):format(entry.name))

        local parts = createTower()
        local pattern = entry.config

        BuildAnimator:play(parts, pattern, nil, function()
            print(("[Demo] %s pattern complete. Cleaning up in 3s..."):format(entry.name))

            task.delay(3, function()
                cleanupParts(parts)
            end)
        end)

        cycleIndex = (cycleIndex % #patternCycle) + 1
        task.wait(8)
    end
end

-- Start demo after a short delay
task.delay(2, runDemo)

print("[BuildAnimator Demo] Started. Watch the tower cycle through animation patterns!")
