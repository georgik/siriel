
from PIL import Image

# Open the original GIF file
gif_image = Image.open('TEXTURA2.GIF')

rgba_image = gif_image.convert('RGBA')

# Convert and save as WebP with lossless compression
rgba_image.save('texture2.webp', 'webp', lossless=True, quality=100)

