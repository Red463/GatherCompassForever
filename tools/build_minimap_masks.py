"""Original geometric masks; never copies or changes the native minimap mask."""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.test-deps'))
from PIL import Image
quadrants=[(1,1,1,1),(0,0,0,0),(1,0,0,0),(0,0,1,0),(0,1,0,0),(0,0,0,1),(1,1,0,0),(0,0,1,1),(1,0,1,0),(0,1,0,1),(1,1,1,0),(1,0,1,1),(1,1,0,1),(0,1,1,1)]
tile=256
image=Image.new('RGBA',(tile*4,tile*4))
for slot,rounded in enumerate(quadrants):
    for y in range(tile):
        for x in range(tile):
            nx,ny=(x+.5)/tile*2-1,1-(y+.5)/tile*2
            q=(0 if ny>=0 else 1) if nx<0 else (2 if ny>=0 else 3)
            alpha=255 if not rounded[q] or nx*nx+ny*ny<=1 else 0
            image.putpixel(((slot%4)*tile+x,(slot//4)*tile+y),(255,255,255,alpha))
image.resize((256,256),Image.Resampling.LANCZOS).save(root/'Media/MinimapMasks.tga',compression=None)
