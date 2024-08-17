local avatar = {}

local avatarImage
local avatarQuads = {}
local avatarFrame = 1
local avatarTimer = 0
local avatarPosition = {}
local tileSize = 16

-- Function to load the avatar sprite sheet and initial position
function avatar.load(imagePath, startPosition)
    avatarImage = love.graphics.newImage(imagePath)

    -- Create quads for the first 4 frames of the avatar (assuming 16x16 tiles)
    for i = 0, 3 do
        table.insert(avatarQuads, love.graphics.newQuad(i * tileSize, 0, tileSize, tileSize, avatarImage:getDimensions()))
    end

    -- Set the initial position of the avatar
    avatarPosition.x = startPosition.x
    avatarPosition.y = startPosition.y
end

-- Update function for animation
function avatar.update(dt)
    -- Update the avatar animation frame every 0.1 seconds
    avatarTimer = avatarTimer + dt
    if avatarTimer >= 0.1 then
        avatarTimer = 0
        avatarFrame = avatarFrame + 1
        if avatarFrame > #avatarQuads then
            avatarFrame = 1
        end
    end
end

-- Draw function for the avatar
function avatar.draw()
    love.graphics.draw(avatarImage, avatarQuads[avatarFrame], avatarPosition.x, avatarPosition.y)
end

return avatar
