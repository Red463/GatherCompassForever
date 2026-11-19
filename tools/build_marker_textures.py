"""Original geometric hollow markers; transparent centres preserve tracking dots."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.test-deps'))
from PIL import Image,ImageDraw
for name in ['NodeRing','NodeSquare']:
    image=Image.new('RGBA',(256,256))
    draw=ImageDraw.Draw(image)
    if name=='NodeRing': draw.ellipse((8,8,247,247),outline='white',width=18)
    else: draw.rectangle((8,8,247,247),outline='white',width=18)
    image.resize((64,64),Image.Resampling.LANCZOS).save(root/'Media'/f'{name}.tga',compression=None)
    print(f'{name}: 64x64 RGBA, hollow centre')
