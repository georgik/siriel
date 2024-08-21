local map = {}

local tileset
local tileSize = 16
local tiles = {}
local margin = 8
local tilesetData

-- Function to load the tileset and prepare pixel data
function map.loadTileset(tilesetPath)
    -- Load the image data first
    local imageData = love.image.newImageData(tilesetPath)
    tilesetData = imageData

    -- Create the image from the image data
    tileset = love.graphics.newImage(imageData)

    local tilesetWidth = tileset:getWidth() / tileSize

    for y = 0, (tileset:getHeight() / tileSize) - 1 do
        for x = 0, tilesetWidth - 1 do
            local quad = love.graphics.newQuad(x * tileSize, y * tileSize, tileSize, tileSize, tileset:getWidth(), tileset:getHeight())
            table.insert(tiles, quad)
        end
    end
end

-- Expose tiles and tilesetData to other modules
function map.getTiles()
    return tiles
end

function map.getTilesetData()
    return tilesetData
end

-- Function to load a Lua map file
function map.load(filename)
    print("Loading map file:", filename)
    local status, chunk = pcall(love.filesystem.load, filename)
    if status then
        print("Map file loaded successfully")
        local env = {}
        setfenv(chunk, env)
        local success, result = pcall(chunk)
        if success then
            if env.level then
                print("Level data loaded successfully")
                return env.level
            else
                print("Error: 'level' table not found in the map file")
            end
        else
            print("Error executing map file:", result)
        end
    else
        print("Failed to load map file:", chunk)
    end
    return nil
end

-- Function to draw the map
function map.draw(mapData)
    for y, line in ipairs(mapData) do
        for x = 1, #line do
            local char = string.sub(line, x, x)
            local tileIndex = string.byte(char) - string.byte('.')
            if tileIndex >= 0 and tileIndex < #tiles then
                love.graphics.draw(tileset, tiles[tileIndex + 1], (x - 1) * tileSize + margin, (y - 1) * tileSize + margin)
            end
        end
    end
end

return map
