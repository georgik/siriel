local objects = {}

local staticObjects = {}
local animatedObjects = {}
local tileSize = 16
local staticTileset
local animatedTileset
local animationQuads = {}

-- Mapping of object names to their tile indices
local objectTileIndexMap = {
    pear = 1,
    cherry = 2,
    coin = 6,
    exit = 10
}

-- Function to load objects
function objects.load(objectData)
    staticTileset = love.graphics.newImage("assets/objects-static.png")
    animatedTileset = love.graphics.newImage("assets/objects-animation.png")

    -- Create quads for the animated objects
    for row = 0, 1 do
        for i = 0, 4 do
            local quad = {}
            for frame = 0, 3 do
                table.insert(quad, love.graphics.newQuad(i * tileSize + frame * tileSize, row * tileSize, tileSize, tileSize, animatedTileset:getDimensions()))
            end
            table.insert(animationQuads, quad)
        end
    end

    -- Process each object from the level
    for _, obj in ipairs(objectData) do
        if obj.animated then
            -- Handle animated objects
            local tileIndex = objectTileIndexMap[obj.name] + 4
            table.insert(animatedObjects, {
                quads = animationQuads[tileIndex],
                frame = 1,
                x = obj.position.x * 8 + 8,
                y = obj.position.y * 8 + 16,
                timer = 0
            })
        else
            -- Handle static objects
            local tileIndex = objectTileIndexMap[obj.name]
            if tileIndex then
                table.insert(staticObjects, {
                    quad = love.graphics.newQuad(tileIndex * tileSize, 0, tileSize, tileSize, staticTileset:getDimensions()),
                    x = obj.position.x * 8 + 8,
                    y = obj.position.y * 8 + 16
                })
            end
        end
    end
end

-- Update function for animated objects
function objects.update(dt)
    for _, obj in ipairs(animatedObjects) do
        -- Increment the timer for the animation
        obj.timer = obj.timer + dt
        if obj.timer >= 0.1 then  -- Adjust the speed of the animation as needed
            obj.timer = 0
            obj.frame = obj.frame + 1
            if obj.frame > #obj.quads then
                obj.frame = 1  -- Loop back to the first frame
            end
        end
    end
end

-- Draw function for objects with logging
function objects.draw()
    for _, obj in ipairs(staticObjects) do
        love.graphics.draw(staticTileset, obj.quad, obj.x, obj.y)
    end

    for _, obj in ipairs(animatedObjects) do
        love.graphics.draw(animatedTileset, obj.quads[obj.frame], obj.x, obj.y)
    end
end


return objects
