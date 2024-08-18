local collision = {}

local tileSize = 16
local margin = 8

function collision.check(mapData, x, y)
    local tileX = math.floor((x - margin) / tileSize) + 1
    local tileY = math.floor((y - margin) / tileSize) + 1

    if mapData[tileY] then
        local tile = string.sub(mapData[tileY], tileX, tileX)
        return tile ~= "."
    end

    return false
end

-- Enhanced collision detection with climbing support
function collision.detectAndResolve(mapData, avatarPos, velocity)
    local offset = 1 -- pixel offset for climbing detection

    -- Check bottom-left and bottom-right corners for ground collision
    if collision.check(mapData, avatarPos.x + offset, avatarPos.y + tileSize) then
        if not collision.check(mapData, avatarPos.x + offset, avatarPos.y + tileSize - offset) then
            avatarPos.y = avatarPos.y - offset
        else
            velocity.y = 0
        end
    elseif collision.check(mapData, avatarPos.x + tileSize - offset, avatarPos.y + tileSize) then
        if not collision.check(mapData, avatarPos.x + tileSize - offset, avatarPos.y + tileSize - offset) then
            avatarPos.y = avatarPos.y - offset
        else
            velocity.y = 0
        end
    end

    -- Update avatar position based on collision resolution
    return avatarPos, velocity
end

return collision
