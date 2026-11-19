"""Profile the real provider/store/Core import path with a synthetic all-zone pack."""
from pathlib import Path
import argparse
import os
import sys
import time

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-deps'))
from lupa.lua51 import LuaRuntime

os.chdir(root)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--rows', type=int, default=20000)
parser.add_argument('--check', action='store_true', help='Require completion within 120 simulated 60 Hz frames')
args = parser.parse_args()
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r'''
A={};for _,name in ipairs({'Store','Imports'}) do assert(loadfile(name..'.lua'))('Gatherly',A) end
clock=0;frames=0;distanceCalls=0;refreshes=0;maps=0;nameCalls=0
A.Store.distance=function(a,b) distanceCalls=distanceCalls+1;return math.sqrt(((a.x-b.x)*10000)^2+((a.y-b.y)*10000)^2) end
A.db=A.Store.Open();A.initialized=true
A.Client={Position=function() return nil end,Now=function() return clock end,Facing=function() end,Distance=A.Store.distance,Size=function() return 10000,10000 end}
A.UI={Refresh=function() refreshes=refreshes+1 end,DisplayRoute=function() end}
A.Arrow={Update=function() end};A.Map={Refresh=function() maps=maps+1 end}
A.detector={Expire=function() end,IsGathering=function() return false end}
GetTime=function() return clock end;debugprofilestop=function() return os.clock()*1000 end
assert(loadfile('Core.lua'))('Gatherly',A)
GatherMateData2HerbDB={};GatherMateData2MineDB={}
GatherMate2={gmdbs={},GetNodesForZone=function() return pairs({}) end,
 DecodeLoc=function(_,loc) return math.floor(loc/1000000)/10000,math.floor(loc%1000000/100)/10000 end,
 GetNameForNode=function(_,_,id) nameCalls=nameCalls+1;return 'Resource '..id end}
function populate(count)
 for i=1,count do
  local zone=(i-1)%16+1;local n=math.floor((i-1)/16);local x=(n%100+1)*90;local y=(math.floor(n/100)+1)*90
  local rows=GatherMateData2HerbDB[zone] or {};GatherMateData2HerbDB[zone]=rows;rows[x*1000000+y*100]=401+n%3
 end
end
function runImport()
 frames=0;distanceCalls=0;refreshes=0;maps=0;nameCalls=0
 A.Import()
 while A.importJob and frames<20000 do frames=frames+1;clock=clock+1/60;A.Tick(1/60) end
 local count=0;for _,rows in pairs(A.db.nodes) do count=count+#rows end
 return frames,distanceCalls,refreshes,maps,nameCalls,count,A.status
end
''')
lua.globals().populate(args.rows)
results = []
for label in ('initial', 'repeat'):
    start = time.perf_counter()
    frames, distances, refreshes, maps, names, nodes, status = lua.globals().runImport()
    elapsed = (time.perf_counter() - start) * 1000
    results.append(frames)
    print(f'{label}: {args.rows} rows, {nodes} stored, {frames} frames ({frames/60:.2f}s simulated), {elapsed:.1f}ms CPU/wall; distances={distances}, name lookups={names}, UI={refreshes}, map={maps}')
    assert not lua.globals().A.importJob, status
if args.check:
    assert max(results) <= 120, 'Import pacing exceeds two seconds at 60 Hz'
