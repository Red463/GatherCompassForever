"""Build a soft radial UI field, with transparent edges, without source artwork."""
from pathlib import Path
import math
import sys
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-deps'))
from PIL import Image
size = 128
image = Image.new('RGBA', (size, size))
for y in range(size):
    for x in range(size):
        radius = math.hypot((x+.5-size/2)/(size/2), (y+.5-size/2)/(size/2))
        alpha = max(0, math.exp(-radius*radius*4)-math.exp(-4))/(1-math.exp(-4)) if radius < 1 else 0
        image.putpixel((x,y), (255,255,255,round(alpha*255)))
image.save(root / 'Media/HeatBlob.tga', compression=None)
