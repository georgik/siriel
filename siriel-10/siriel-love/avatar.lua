local avatar = {}

local avatarImage
local avatarQuads = { idle = {}, left = {}, right = {} }
local avatarFrame = 1
local avatarTimer = 0
local avatarPosition = {}
local tileSize = 16
local velocity = { x = 0, y = 0 }
local acceleration = { x = 0, y = 800 } -- Gravity
local speed = 100
local jumpVelocity = -300
local isJumping = false
local currentAnimation = "idle" -- Possible values: "idle", "left", "right"
local mapData

-- Function to load the avatar sprite sheet and initial position
function avatar.load(imagePath, startPosition)
    avatarImage = love.graphics.newImage(imagePath)

    -- Create quads for the first 4 frames of each animation (idle, left, right)
    for i = 0, 3 do
        table.insert(avatarQuads.idle, love.graphics.newQuad(i * tileSize, 0, tileSize, tileSize, avatarImage:getDimensions()))
        table.insert(avatarQuads.left, love.graphics.newQuad(i * tileSize + tileSize * 4, 0, tileSize, tileSize, avatarImage:getDimensions()))
        table.insert(avatarQuads.right, love.graphics.newQuad(i * tileSize + tileSize * 8, 0, tileSize, tileSize, avatarImage:getDimensions()))
    end

    -- Set the initial position of the avatar
    avatarPosition.x = startPosition.x
    avatarPosition.y = startPosition.y
end

-- Update function for animation and movement
function avatar.update(dt, map)
    -- Store map data for collision detection
    mapData = map

    -- Update animation
    avatarTimer = avatarTimer + dt
    if avatarTimer >= 0.1 then
        avatarTimer = 0
        avatarFrame = avatarFrame + 1
        if avatarFrame > #avatarQuads[currentAnimation] then
            avatarFrame = 1
        end
    end

    -- Update position based on velocity
    velocity.y = velocity.y + acceleration.y * dt

    avatarPosition.x = avatarPosition.x + velocity.x * dt
    avatarPosition.y = avatarPosition.y + velocity.y * dt

    -- Collision detection
    if checkCollision(avatarPosition.x, avatarPosition.y + tileSize) then
        velocity.y = 0
        isJumping = false
        avatarPosition.y = math.floor(avatarPosition.y / tileSize) * tileSize
    end

    -- Prevent falling out of the map
    if avatarPosition.y > love.graphics.getHeight() then
        avatarPosition.y = love.graphics.getHeight() - tileSize
        velocity.y = 0
        isJumping = false
    end
end

-- Draw function for the avatar
function avatar.draw()
    love.graphics.draw(avatarImage, avatarQuads[currentAnimation][avatarFrame], avatarPosition.x, avatarPosition.y)
end

-- Key pressed handler for movement and jumping
function avatar.keypressed(key)
    if key == "left" or key == "a" then
        velocity.x = -speed
        currentAnimation = "left"
    elseif key == "right" or key == "d" then
        velocity.x = speed
        currentAnimation = "right"
    elseif (key == "up" or key == "w") and not isJumping then
        velocity.y = jumpVelocity
        isJumping = true
    end
end

-- Key released handler for stopping movement
function avatar.keyreleased(key)
    if key == "left" or key == "a" or key == "right" or key == "d" then
        velocity.x = 0
        if not isJumping then
            currentAnimation = "idle"
        end
    end
end

-- Check collision with the map tiles
function checkCollision(x, y)
    local tileX = math.floor(x / tileSize) + 1
    local tileY = math.floor(y / tileSize) + 1

    if mapData[tileY] then
        local tile = string.sub(mapData[tileY], tileX, tileX)
        return tile ~= "."
    end

    return false
end

return avatar
