"""Check the real heat texture composed with the Lua renderer's colours and alpha."""
from pathlib import Path
import os
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-deps'))
from lupa.lua51 import LuaRuntime
from PIL import Image

os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute("dofile('tests/wow.lua');fakeUI();A={};assert(loadfile('Heatmap.lua'))('Gatherly',A)")
texture = Image.open(root / 'Media/HeatBlob.tga').convert('RGBA')


def draw(points, width=6000, height=4000, corridor=False):
    route = lua.table_from({
        'width': width, 'height': height,
        'points': lua.table_from([lua.table_from({'x': x, 'y': y, 'density': d}) for x, y, d in points]),
    })
    if corridor:
        route['corridor'] = True
        route['coverageRadius'] = 180
        route['heatRadius'] = 117
        route['heatSpacing'] = 70
    pool = lua.table()
    lua.globals().A.Heatmap.Draw(pool, lua.globals().UIParent, route,
                               lambda p: (p.x * width, -p.y * height), lambda r: (r, r))
    return list(pool.values())


def opacity(textures, x, y):
    transmission = 1.0
    for t in textures:
        _, _, _, cx, cy = list(t.point.values())
        u, v = (x - cx) / t.width + .5, (y - cy) / t.height + .5
        if 0 <= u < 1 and 0 <= v < 1:
            alpha = texture.getpixel((int(u * texture.width), int(v * texture.height)))[3] / 255
            transmission *= 1 - alpha * t.vertexColor[4]
    return 1 - transmission


fixtures = {
    'straight': [(.1, .5, 1), (.9, .5, 1)],
    'bend': [(.1, .5, 1), (.5, .5, 1), (.5, .2, 1)],
    'dense crossing': [(.3, .3, 20), (.7, .7, 20), (.3, .7, 20), (.7, .3, 20)],
}
for mode in ('legacy', 'corridor'):
    for name, points in fixtures.items():
        textures = draw(points, corridor=mode == 'corridor')
        values = []
        for a, b in zip(points, points[1:]):
            for i in range(21):
                f = i / 20
                values.append(opacity(textures, (a[0] + (b[0] - a[0]) * f) * 6000,
                                      -(a[1] + (b[1] - a[1]) * f) * 4000))
        low, high = min(values), max(values)
        print(f'World heat {mode}/{name}: corridor opacity {low:.3f}-{high:.3f}')
        assert low >= .55, f'{mode}/{name}: heat corridor fades to {low:.3f}; hard to distinguish from terrain'
        assert high <= .93, f'{mode}/{name}: heat corridor obscures terrain at {high:.3f}'

single = draw([(.5, .5, 1)])
assert .7 <= opacity(single, 3000, -2000) <= .9
assert opacity(single, 3120, -2000) == 0, 'Heat must fade to transparent outside its radius'
assert opacity(single, 3108, -2000) < .05, 'Heat edges must stay soft'
print('World heat: readable corridor and transparent edges verified with shipped TGA')
