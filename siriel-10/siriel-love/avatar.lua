local avatar = {}

local avatarImage
local avatarQuads = { idle = {}, left = {}, right = {} }
local avatarFrame = 1
local avatarTimer = 0
local avatarPosition = {}
local tileSize = 16
local velocity = { x = 0, y = 0 }
local acceleration = { x = 0, y = 4 } -- Gravity
local checkPointLeft = 0
local checkPointRight = 14
local tilesPerRow = 19
local stepUp = 4
local speed = 4
local jumpVelocity = -300
local isJumping = false
local isFalling = false
local isParachuting = false
local parachuteSpeed = 100
local currentAnimation = "idle" -- Possible values: "idle", "left", "right"
local mapData
local tiles, tilesetData

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

-- Function to initialize tiles and tilesetData from the map module
function avatar.init(mapTiles, mapTilesetData)
    tiles = mapTiles
    tilesetData = mapTilesetData
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

    -- Check if avatar is on solid ground
    local onGround = checkCollision(avatarPosition.x + checkPointLeft, avatarPosition.y + tileSize) and
                     checkCollision(avatarPosition.x + checkPointRight, avatarPosition.y + tileSize)

    -- Apply gravity if not on solid ground and not parachuting
    if not onGround then
        if isParachuting then
            velocity.y = parachuteSpeed
        else
            velocity.y = acceleration.y
        end
        isJumping = true
        isFalling = true
    else
        velocity.y = 0
        isJumping = false
        isFalling = false
        isParachuting = false -- Stop parachuting when on the ground
    end

    -- Calculate new X position
    local newX = avatarPosition.x + velocity.x

    -- Horizontal collision detection and slope climbing
    if velocity.x ~= 0 then
        if not checkCollision(newX + checkPointLeft, avatarPosition.y + tileSize - 1) and not checkCollision(newX +  checkPointRight, avatarPosition.y + tileSize - 1) then
            avatarPosition.x = newX
        else
            -- Check for slope climbing
            if not isJumping and not checkCollision(newX + checkPointLeft, avatarPosition.y + tileSize - stepUp) and not checkCollision(newX + checkPointRight, avatarPosition.y + tileSize - 2) then
                avatarPosition.x = newX
                avatarPosition.y = avatarPosition.y - stepUp
            else
                velocity.x = 0
            end
        end
    end

    -- Calculate new Y position if gravity is applied
    if isFalling then
        local newY = avatarPosition.y + velocity.y

        -- Vertical collision detection
        if velocity.y < 0 then -- Jumping
            if checkCollision(avatarPosition.x + checkPointLeft, newY + tileSize - 1) or checkCollision(avatarPosition.x + checkPointRight, newY + tileSize - 1) then
                velocity.y = 0
            else
                if not checkCollision(avatarPosition.x + checkPointLeft, newY + tileSize - 1) and not checkCollision(avatarPosition.x + checkPointRight, newY + tileSize - 1) then
                    avatarPosition.y = newY
                end
            end
        else -- Falling
            if not checkCollision(avatarPosition.x + checkPointLeft, newY + tileSize - 1) and not checkCollision(avatarPosition.x + checkPointRight, newY + tileSize - 1) then
                avatarPosition.y = newY
            end
        end

    end

    -- Prevent falling out of the map
    if avatarPosition.y > love.graphics.getHeight() then
        avatarPosition.y = love.graphics.getHeight() - tileSize
        velocity.y = 0
        isJumping = false
    else
        if avatarPosition.y < 0 then
            avatarPosition = 0
        end
    end

    if avatarPosition.x > love.graphics.getWidth() then
        avatarPosition.x = love.graphics.getWidth()
    else
        if avatarPosition.x < 0 then
            avatarPosition.x = 0
        end
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

-- Check collision with the map tiles based on pixel transparency
function checkCollision(x, y)
    x = math.floor(x)
    y = math.floor(y)
    local tileX = math.floor((x - 8) / tileSize) + 1
    local tileY = math.floor((y - 8) / tileSize) + 1

    if mapData[tileY] then
        local tile = string.sub(mapData[tileY], tileX, tileX)
        if tile == "." then
            return false -- No collision for fully transparent tile
        else
            -- Determine the exact pixel position within the tile
            local pixelX = (x - 8) % tileSize
            local pixelY = (y - 8) % tileSize

            -- Get the tile index
            local tileIndex = string.byte(tile) - string.byte(".")

            if tileIndex >= 0 and tileIndex < #tiles then
                print("X,Y", tileIndex * tileSize + pixelX, pixelY)

                -- Get pixel color
                local r, g, b, a = tilesetData:getPixel((tileIndex % tilesPerRow) * tileSize + pixelX, (tileIndex / tilesPerRow) * tileSize + pixelY)
                -- Check if the pixel is not fully transparent
                
                if a > 0 then
                    return true
                end

            end
        end
    end

    return false
end


function avatar.isFalling()
    return velocity.y > 0
end

function avatar.getPosition()
    return { x = avatarPosition.x, y = avatarPosition.y }
end

function avatar.startParachute()
    isParachuting = true
    velocity.y = parachuteSpeed
end

return avatar
