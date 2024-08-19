local map = require("map")
local avatar = require("avatar")
local parachute = require("parachute")
local objects = require("objects")

-- Load function
function love.load()
    love.window.setMode(640, 480, {fullscreen = false, vsync = true})
    
    -- Load the map
    local level = map.load("fm_lua/FMIS01.lua")
    if not level then
        error("Failed to load level")
    end

    -- Load the tileset for the map and the avatar
    map.loadTileset("assets/texture2.png")
    avatar.load("assets/siriel-avatar.png", level.start_position)
    objects.load(level.objects)

    -- Store the map data for rendering
    mapData = level.map
end

-- Update function (for animation and controls)
function love.update(dt)
    avatar.update(dt, mapData)
    objects.update(dt)
end

-- Draw function
function love.draw()
    -- Draw the map
    map.draw(mapData)

    -- Draw the objects
    objects.draw()

    -- Draw the avatar
    avatar.draw()
    
    -- Draw the parachute
    parachute.draw()
end

-- Key pressed event
function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    avatar.keypressed(key)
end

-- Key released event
function love.keyreleased(key)
    avatar.keyreleased(key)
end
