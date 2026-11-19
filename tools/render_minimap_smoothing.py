"""Compare real minimap paint output over a flat diagnostic background."""
from pathlib import Path
import math
import os
import subprocess
import sys
import time

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-deps'))
from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont

os.chdir(root)
before = subprocess.check_output(['git', 'show', '35f9b9413b4e7baca5b1a50bd7b23d8a399369ee:MiniHeat.lua'], text=True)
after = (root / 'MiniHeat.lua').read_text()
width, height = 223, 217
images = []
for name, source in [('Before: flat cells', before), ('After: blended strips', after)]:
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.execute("dofile('tests/wow.lua');fakeUI();A={};for _,n in ipairs({'Store','Heatmap'}) do assert(loadfile(n..'.lua'))('Gatherly',A) end")
    lua.execute("assert(loadstring(...))('Gatherly',A)", source)
    lua.execute("""
route={width=1000,height=500,corridor=true,heatRadius=117,coverageRadius=180,points={{x=.3,y=.5},{x=.7,y=.5}}}
pool={}
function paint()
 local field=A.MiniHeat.Field(route,function(p) return (p.x-.5)*500,0 end,223,217,'SQUARE',{},.65,function(r) return r*.5,r*.5 end)
 A.MiniHeat.Draw(pool,Minimap,field,'SQUARE',{.1,.9,1})
end
paint()
""")
    started = time.perf_counter()
    for _ in range(30):
        lua.globals().paint()
    print(f'{name}: {(time.perf_counter()-started)*1000/30:.2f} ms/refresh in Lua 5.1 fixture')
    im = Image.new('RGB', (width, height), '#353b29')
    for key, texture in lua.globals().pool.items():
        if not isinstance(key, (int, float)) or not texture.IsShown(texture):
            continue
        left, top = width/2+texture.point[4], height/2-texture.point[5]
        gradient = texture.gradient
        for y in range(max(0, math.ceil(top-.5)), min(height, math.ceil(top+texture.height-.5))):
            for x in range(max(0, math.ceil(left-.5)), min(width, math.ceil(left+texture.width-.5))):
                if gradient:
                    f = (x+.5-left)/texture.width
                    rgba = [gradient.left[i]*(1-f)+gradient.right[i]*f for i in range(1, 5)]
                else:
                    rgba = list(texture.color.values())
                alpha = rgba[3]
                im.putpixel((x, y), tuple(round(255*c*alpha+base*(1-alpha)) for c, base in zip(rgba[:3], (53, 59, 41))))
    images.append(im.resize((width*2, height*2), Image.Resampling.NEAREST))

out = Image.new('RGB', (width*4+48, height*2+84), '#141b15')
draw = ImageDraw.Draw(out)
font = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 15)
for i, title in enumerate(['Before: flat cells', 'After: blended strips']):
    x = 16+i*(width*2+16)
    draw.text((x, 12), title, font=font, fill='#f1d18b')
    out.paste(images[i], (x, 38))
draw.text((16, height*2+51), 'Actual Lua paint output at 2x scale. Flat background isolates banding; native client rendering still needs checking.', font=font, fill='#c4c6b7')
path = root / 'docs/images/minimap-smoothing.png'
out.save(path)
print(path)
