local map = require("map")
local avatar = require("avatar")
local parachute = require("parachute")

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

    -- Load the parachute
    parachute.load()

    -- Store the map data for rendering
    mapData = level.map
end

function love.update(dt)
    avatar.update(dt, mapData)
    parachute.update(dt, avatar.isFalling(), avatar.getPosition())
end

function love.draw()
    map.draw(mapData)
    avatar.draw()
    parachute.draw()
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end

    avatar.keypressed(key)
end

function love.keyreleased(key)
    avatar.keyreleased(key)
end
