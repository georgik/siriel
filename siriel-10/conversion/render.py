import pygame
import lupa
from lupa import LuaRuntime
from PIL import Image

# Initialize Lua runtime
lua = LuaRuntime(unpack_returned_tuples=True)

# Load the Lua file
with open('fm_lua/FMIS01.lua', 'r', encoding='utf-8') as file:
    lua_content = file.read()

# Execute the Lua code
lua.execute(lua_content)

# Get the level data from Lua
level = lua.globals().level

# Extract map data and starting position
lua_map_data = level.map
start_position = level.start_position

# Convert Lua table to Python list
map_data = []
for i in range(1, len(lua_map_data) + 1):
    map_data.append(lua_map_data[i])

# Debug: Print the map data to check its contents
print("Map Data:")
for idx, line in enumerate(map_data):
    print(idx + 1, line, type(line))

# Ensure map_data is a list of strings
map_data = [str(line).strip() for line in map_data if isinstance(line, str) and line.strip()]

# Debug: Print the cleaned map data to check its contents
print("Cleaned Map Data:")
for line in map_data:
    print(line)

map_width = max(len(line) for line in map_data)
map_height = len(map_data)

# Constants
TILE_SIZE = 16  # Tiles are 16x16 in the texture
TILES_PER_ROW = 19
SCREEN_WIDTH = map_width * TILE_SIZE
SCREEN_HEIGHT = map_height * TILE_SIZE
AVATAR_COLOR = (0, 255, 0)
BACKGROUND_COLOR = (0, 0, 0)

# Load the texture
texture = Image.open('img/texture2.webp')
texture = texture.convert('RGBA')
texture_width, texture_height = texture.size

# Convert texture to a list of surfaces
tile_surfaces = []
for y in range(0, texture_height, TILE_SIZE):
    for x in range(0, texture_width, TILE_SIZE):
        rect = pygame.Rect(x, y, TILE_SIZE, TILE_SIZE)
        sub_surface = pygame.Surface((TILE_SIZE, TILE_SIZE), pygame.SRCALPHA)
        sub_surface.blit(pygame.image.fromstring(texture.tobytes(), texture.size, texture.mode), (0, 0), rect)
        tile_surfaces.append(sub_surface)

# Initialize Pygame
pygame.init()
screen = pygame.display.set_mode((SCREEN_WIDTH, SCREEN_HEIGHT))
pygame.display.set_caption("Map Renderer")

# Main loop
running = True
avatar_pos = [start_position.x * TILE_SIZE, start_position.y * TILE_SIZE]

while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    screen.fill(BACKGROUND_COLOR)

    # Render the map
    for y, line in enumerate(map_data):
        for x, char in enumerate(line):
            tile_index = ord(char) - ord('.')
            
            if 0 <= tile_index < len(tile_surfaces):
                screen.blit(tile_surfaces[tile_index], (x * TILE_SIZE, y * TILE_SIZE))

    # Render the avatar
    pygame.draw.rect(screen, AVATAR_COLOR, (*avatar_pos, TILE_SIZE, TILE_SIZE))

    pygame.display.flip()

pygame.quit()
