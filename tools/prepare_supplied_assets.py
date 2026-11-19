"""Lossless source preservation and standard WoW texture format/size preparation.

Format conversion only: both supplied transparent originals are kept whole.
"""
from pathlib import Path
import sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.test-deps'))
from PIL import Image
source=root/'assets'/'source';source.mkdir(parents=True,exist_ok=True)
inputs=[('Gatherly Badge.png','Icon',(256,256)),('Gatherly Logo.png','LogoSheet',(2048,1024)),('Gatherly Badge.png','EmptyEmblem',(1024,1024))]
for filename,name,size in inputs:
    preserved=source/filename
    if not preserved.exists():raise FileNotFoundError(f'Place the original artwork at {preserved} before building textures.')
    im=Image.open(preserved).convert('RGBA')
    scale=min(size[0]/im.width,size[1]/im.height)
    resized=im.resize((round(im.width*scale),round(im.height*scale)),Image.Resampling.LANCZOS)
    canvas=Image.new('RGBA',size)
    canvas.paste(resized,((size[0]-resized.width)//2,(size[1]-resized.height)//2))
    canvas.save(root/'Media'/f'{name}.tga',compression=None)
    print(f'{name}.tga: {size[0]}x{size[1]}, RGBA, original transparency retained')
(root/'Media'/'README.txt').write_text('Gatherly artwork supplied by the user, 19 November 2026. LogoSheet: complete Gatherly Logo.png. Icon and EmptyEmblem: Gatherly Badge.png. Originals preserved unchanged in assets/source. Conversion uses aspect-preserving resizing, transparent padding and uncompressed RGBA TGA. Header.tga is the existing neutral contour background. NodeRing.tga and NodeSquare.tga are original hollow 64x64 RGBA geometry from build_marker_textures.py. Native Classic textures are referenced from the client, not bundled.\n',encoding='utf-8')
