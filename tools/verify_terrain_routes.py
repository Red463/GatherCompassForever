"""Reproduce the all-herb Ashenvale runtime benchmark and independently audit geometry.

Reads the preserved experiment's node report by default. No game files or saved
data are modified. Navigation is checked against decoded packaged mask bits by
closed rectangle/segment intersection, independently of the Lua supercover.
"""
from pathlib import Path
import argparse
import json
import math
import os
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / '.test-deps'))
from lupa.lua51 import LuaRuntime

ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'


def intersects(ax, ay, bx, by, x, y):
    lo, hi = 0.0, 1.0
    for origin, delta, lower, upper in ((ax, bx - ax, x, x + 1), (ay, by - ay, y, y + 1)):
        if abs(delta) < 1e-15:
            if origin < lower or origin > upper:
                return False
        else:
            first, last = sorted(((lower - origin) / delta, (upper - origin) / delta))
            lo, hi = max(lo, first), min(hi, last)
            if lo > hi + 1e-12:
                return False
    return True


def audit(points, zone, loop):
    w, h = int(zone['w']), int(zone['h'])
    permitted = bytearray(w * h)
    for y in range(h):
        row = zone['rows'][y + 1] or ''
        for x in range(w):
            index = x // 6
            if index < len(row):
                permitted[y * w + x] = (ALPHABET.index(row[index]) >> (5 - x % 6)) & 1
    checked = 0
    pairs = list(zip(points, points[1:]))
    if loop and len(points) > 1:
        pairs.append((points[-1], points[0]))
    for first, last in pairs:
        ax, ay, bx, by = first['x'] * w, first['y'] * h, last['x'] * w, last['y'] * h
        for y in range(max(0, math.floor(min(ay, by)) - 1), min(h - 1, math.floor(max(ay, by))) + 1):
            for x in range(max(0, math.floor(min(ax, bx)) - 1), min(w - 1, math.floor(max(ax, bx))) + 1):
                if not permitted[y * w + x]:
                    assert not intersects(ax, ay, bx, by, x, y), f'Blocked mask cell {x},{y} touched by route'
                checked += 1
    return len(pairs), checked


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--nodes', type=Path, default=ROOT.parent / 'output/ashenvale-route-preview/route-report.json')
    parser.add_argument('--map', type=int, default=1440)
    parser.add_argument('--coverage', type=float, default=180)
    parser.add_argument('--start', help='Normalized x,y; otherwise use the report example_start')
    args = parser.parse_args()
    report = json.loads(args.nodes.read_text(encoding='utf-8'))
    source = report['nodes'] if isinstance(report, dict) else report
    if not args.start and (not isinstance(report, dict) or 'example_start' not in report):
        parser.error('--start x,y is required when the node file has no example_start')
    start = dict(zip(('x', 'y'), map(float, args.start.split(',')))) if args.start else report['example_start']
    lua = LuaRuntime(unpack_returned_tuples=True)
    os.chdir(ROOT)
    lua.execute('A={};for _,n in ipairs({"Store","Data/Terrain","Terrain","Coverage","Corridor","Planner"}) do assert(loadfile(n..".lua"))("Gatherly",A) end')
    nodes = []
    for index, node in enumerate(source):
        nodes.append(lua.table_from(dict(mapID=args.map, x=node['x'], y=node['y'], kind='herb',
                                         materialID='gm:herb:' + str(node.get('kind', 'unknown')),
                                         name=node.get('name', 'Herb'), key='n' + str(index))))
    lua.globals().nodes = lua.table_from(nodes)
    lua.globals().start = lua.table_from(dict(mapID=args.map, **start))
    lua.globals().coverage = args.coverage
    lua.execute('''A.Terrain.Checkpoint=function() coroutine.yield() end
co=coroutine.create(function() return A.Planner.Generate(nodes,start,function() end,{coverageRadius=coverage}) end)
function step() local ok,a,b=coroutine.resume(co);assert(ok,a);return coroutine.status(co),a,b end''')
    began = time.perf_counter()
    slices = []
    while True:
        before = time.perf_counter()
        status, route, reason = lua.globals().step()
        slices.append((time.perf_counter() - before) * 1000)
        if status == 'dead':
            break
    elapsed = time.perf_counter() - began
    assert route is not None, reason
    lua.execute('A.Terrain.Checkpoint=nil')
    lua.execute('assert(A.Terrain.Validate(...))', route)
    points = [dict(route['points'][i]) for i in range(1, len(route['points']) + 1)]
    zone = lua.globals().A.Terrain.Zone(args.map)
    segments, cells = audit(points, zone, route['loop'])
    print(json.dumps(dict(selected=len(nodes), included=route['includedCount'], omitted=route['omittedCount'],
                          navigationPoints=len(points), closedLoop=bool(route['loop']),
                          auditedSegments=segments, rectangleCellsChecked=cells,
                          planningSeconds=round(elapsed, 3), checkpointSlices=len(slices),
                          p99SliceMilliseconds=round(sorted(slices)[int((len(slices) - 1) * .99)], 3),
                          maxSliceMilliseconds=round(max(slices), 3)), indent=2))


if __name__ == '__main__':
    main()
