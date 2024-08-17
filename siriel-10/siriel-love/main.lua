local map = require("map")
local avatar = require("avatar")

-- Load function
function love.load()
    -- Load the map
    local level = map.load("fm_lua/FMIS12.lua")
    if not level then
        error("Failed to load level")
    end

    -- Load the tileset for the map and the avatar
    map.loadTileset("assets/texture2.png")
    avatar.load("assets/siriel-avatar.png", level.start_position)

    -- Store the map data for rendering
    mapData = level.map
end

-- Update function (for animation and controls)
function love.update(dt)
    avatar.update(dt, mapData)
end

-- Draw function
function love.draw()
    -- Draw the map
    map.draw(mapData)

    -- Draw the avatar
    avatar.draw()
end

-- Key pressed event
function love.keypressed(key)
    avatar.keypressed(key)
end

-- Key released event
function love.keyreleased(key)
    avatar.keyreleased(key)
end
