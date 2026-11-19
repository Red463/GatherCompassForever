"""Measure the real minimap renderer's blended corridor over dark terrain colours."""
from pathlib import Path
import os
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-deps'))
from lupa.lua51 import LuaRuntime

os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("""
dofile('tests/wow.lua');fakeUI();A={}
for _,name in ipairs({'Store','Resources','Heatmap','MiniHeat'}) do assert(loadfile(name..'.lua'))('Gatherly',A) end
local route={width=1000,height=500,points={{x=.3,y=.5},{x=.7,y=.5}}}
local opacity=A.Resources.Settings({}).miniHeatOpacity
local field=A.MiniHeat.Field(route,function(p) return (p.x-.5)*500,0 end,200,200,'ROUND',{{x=0,y=0,r=4,feather=5}},opacity,function(r) return r*.5,r*.5 end)
pool={};A.MiniHeat.Draw(pool,Minimap,field,'ROUND')
""")


def luminance(rgb):
    linear = [c / 12.92 if c <= .04045 else ((c + .055) / 1.055) ** 2.4 for c in rgb]
    return sum(c * weight for c, weight in zip(linear, (.2126, .7152, .0722)))


# Illustrative forest, cave and swamp tones: these are fixtures, not live map captures.
terrains = {'forest': (26, 32, 11), 'cave': (16, 14, 10), 'swamp': (45, 41, 15)}
textures = [t for key, t in lua.globals().pool.items() if isinstance(key, (int, float))]
centreline = [t for t in textures if 20 <= abs(t.point[4] + t.width / 2) <= 65
              and abs(t.point[5] - t.height / 2) < 5]
assert len(centreline) >= 16, 'The corridor is missing centreline cells'
for name, pixels in terrains.items():
    terrain = [c / 255 for c in pixels]
    ratios = []
    for t in centreline:
        r, g, b, alpha = list(t.color.values())
        result = [c * alpha + base * (1 - alpha) for c, base in zip((r, g, b), terrain)]
        ratios.append((luminance(result) + .05) / (luminance(terrain) + .05))
    low = min(ratios)
    print(f'Minimap heat on {name}: minimum corridor contrast {low:.2f}:1')
    assert low >= 2, f'{name}: minimap heat blends into dark terrain ({low:.2f}:1)'
print('Minimap heat: dark-terrain visibility verified at the default overlay opacity')
