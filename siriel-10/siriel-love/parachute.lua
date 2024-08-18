local parachute = {}

local parachuteQuads = {}
local parachuteImage
local tileSize = 16
local currentFrame = 1
local avatarPosition = { x = 0, y = 0 }

function parachute.load()
    parachuteImage = love.graphics.newImage("assets/siriel-avatar.png")

    for i = 0, 2 do
        table.insert(parachuteQuads, love.graphics.newQuad((i + 8) * tileSize, tileSize, tileSize, tileSize, parachuteImage:getDimensions()))
    end
end

function parachute.update(dt, isFalling, newAvatarPosition)
    avatarPosition = newAvatarPosition
    if isFalling then
        currentFrame = 3
    else
        currentFrame = 1
    end
end

function parachute.draw()
    if currentFrame > 1 then
        love.graphics.draw(parachuteImage, parachuteQuads[currentFrame], avatarPosition.x, avatarPosition.y - tileSize)
    end
end

return parachute
