"""Verify every shipped mask and generator rules independently of game access."""
from pathlib import Path
import json,sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.test-deps'))
sys.path.insert(0,str(ROOT/'tools/terrain'))
from lupa.lua51 import LuaRuntime
from rules import cleanup,encode_rows,slope,ALPHABET,CELL

lua=LuaRuntime(unpack_returned_tuples=True)
data=lua.execute("local A={};assert(loadfile('Data/Terrain.lua'))('Gatherly',A);assert(loadfile('Terrain.lua'))('Gatherly',A);return A")
assert data.TerrainData.version==1 and data.TerrainData.build==70959
meta=json.loads((ROOT/'tools/terrain/zones.json').read_text())
assert meta['build']==70959 and len(meta['zones'])==60
counts={}
for zone in meta['zones']:
    z=data.TerrainData.zones[zone['id']];assert z is not None
    counts[z.status]=counts.get(z.status,0)+1
    if zone['type'] not in (3,6):
        assert data.Terrain.Zone(zone['id'])[0] is None
        continue
    assert z.status in ('complete','partial') and z.name==zone['name']
    assert z.widthYards==zone['west']-zone['east'] and z.heightYards==zone['north']-zone['south']
    assert len(z.rows)==z.h
    permitted=0
    for _,row in z.rows.items():
        assert len(row)==(z.w+5)//6 and set(row)<=set(ALPHABET)
        permitted+=sum(ALPHABET.index(c).bit_count() for c in row)
        if z.w%6:assert ALPHABET.index(row[-1])%(1<<(6-z.w%6))==0
    assert permitted>0
assert counts=={'complete':43,'partial':12,'unavailable':5},counts
# Six-bit row order and padding must agree with the Lua reader.
assert encode_rows(bytes([255,0,128,0,255,0,255]),7,1)==['qg']
assert slope(0,0,0,0,0)==0
import math
rise=math.tan(math.radians(50))*CELL
assert abs(slope(0,rise,0,rise,rise/2)-50)<1e-10
# One/two-cell isolated restrictions disappear; enclosed islands fill;
# edge-connected and liquid-adjacent candidates survive.
raw=bytearray([255]*81);raw[40]=raw[41]=0
clean,stats=cleanup(bytes(raw),9,9);assert clean[40]==clean[41]==255 and stats['tiny_cells_removed']==2
raw=bytearray([0]*81);raw[40]=255;raw[0]=255
clean,stats=cleanup(bytes(raw),9,9);assert clean[40]==0 and clean[0]==255
raw[41]=128
clean,_=cleanup(bytes(raw),9,9);assert clean[40]==255 and clean[41]==128
print('Terrain data: 55 local maps verified (43 complete, 12 partial), 5 overview maps excluded; generator rules verified')
