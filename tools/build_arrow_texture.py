"""Build the original flat navigation arrow from deterministic vector geometry."""
from pathlib import Path
import sys
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-deps'))
from PIL import Image, ImageDraw

# North is up at zero rotation. Padding keeps the silhouette inside the
# texture's inscribed circle so rotating it never clips a tip or wing.
points = [(32, 5), (54, 52), (32, 42), (10, 52)]
scale = 8
image = Image.new('RGBA', (64 * scale, 64 * scale))
draw = ImageDraw.Draw(image)
path = [(x * scale, y * scale) for x, y in points]
draw.polygon(path, fill='#FFD15C')
draw.line(path + [path[0]], fill='#33260C', width=scale, joint='curve')
image = image.resize((64, 64), Image.Resampling.LANCZOS)
image.save(root / 'Media/GuideArrow.tga', compression=None)
(root / 'assets/GuideArrow.svg').write_text(
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">\n'
    '  <path d="M32 5 L54 52 L32 42 L10 52 Z" fill="#FFD15C" '
    'stroke="#33260C" stroke-width="1" stroke-linejoin="round"/>\n'
    '</svg>\n', encoding='utf-8')
print('GuideArrow: original flat gold 64x64 RGBA, transparent padding')
