"""Offline Lua 5.1 refresh profile; frame doubles are not live-client timings."""
from pathlib import Path
import os
import argparse
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-deps'))
from lupa.lua51 import LuaRuntime
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--baseline', help='Git revision supplying Map.lua and MiniHeat.lua')
args = parser.parse_args()
sources = {}
if args.baseline:
    for name in ('Map', 'MiniHeat'):
        sources[name] = subprocess.check_output(['git', 'show', args.baseline+':'+name+'.lua'], text=True)
lua.globals().profileSources = lua.table_from(sources)
print('Revision:', args.baseline or 'working tree')
lua.execute('''
function module(name,A)
 if name=='Map' then for _,n in ipairs({'Resources','MarkerGroups','SkillTooltip','Selection','Heatmap','MiniHeat','MinimapPins'}) do module(n,A) end end
 local source=profileSources[name];local load=source and assert(loadstring(source)) or assert(loadfile(name..'.lua'));load('Gatherly',A)
end
function point(x,y) return {mapID=1,x=x,y=y or .5,kind='travel'} end
dofile('tests/wow.lua');fakeUI();A={};for _,n in ipairs({'Store','Client','Follower','Map'}) do module(n,A) end
local p=point(.5);A.Client.Position=function() return p end;A.Client.Size=function() return 6000,4000 end;A.Client.Facing=function() return 0 end
A.Client.Distance=function(a,b) return math.sqrt(((a.x-b.x)*6000)^2+((a.y-b.y)*4000)^2) end
C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end
LibStub=function() return {AddWorldMapIconMap=function() end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
A.db=A.Store.Open();A.db.nodes[1]={}
for i=1,1500 do A.db.nodes[1][i]={key='n'..i,mapID=1,x=.05+(i%50)*.018,y=.05+math.floor(i/50)*.03,kind='herb',materialID='gm:herb:401',name='Peacebloom',imported=true} end
local points={};for row=0,7 do for col=0,14 do points[#points+1]=point(.1+(row%2==0 and col or 14-col)*.8/14,.1+row*.8/7) end end
local route={mapID=1,width=6000,height=4000,corridor=true,heatRadius=117,heatSpacing=70,coverageRadius=180,points=points,loop=true}
local f=A.Follower.New(route,p,A.Client.Distance);A.db.settings.routeStyle='heatmap';WorldMapFrame:Hide();A.Map.Refresh(A.db,route,f)
local stats={}
local function wrap(obj,key,label)
 local fn=obj[key];obj[key]=function(...)
  local m=collectgarbage('count');local t=os.clock();local a,b,c=fn(...)
  local s=stats[label] or {time=0,mem=0,count=0};stats[label]=s;s.time=s.time+os.clock()-t;s.mem=s.mem+collectgarbage('count')-m;s.count=s.count+1;return a,b,c
 end
end
wrap(A.MiniHeat,'Field','heat field');wrap(A.MiniHeat,'Draw','heat draw');wrap(A.Store,'Select','node select');wrap(A.MarkerGroups,'Build','group markers');wrap(A.Resources,'Presentation','marker style')
collectgarbage('collect');collectgarbage('stop');local t=os.clock();local m=collectgarbage('count')
for i=1,20 do p.x=p.x+.0001;A.Map.Refresh(A.db,route,f) end
print(string.format('Moving Map.Refresh, hidden world: %.2f ms, %.0f KiB per refresh',(os.clock()-t)*1000/20,(collectgarbage('count')-m)/20))
for label,s in pairs(stats) do print(string.format('  %s: %.2f ms/refresh, %.0f KiB/refresh (%d calls)',label,s.time*1000/20,s.mem/20,s.count)) end
collectgarbage('restart')
''')
