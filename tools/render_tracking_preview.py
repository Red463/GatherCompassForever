"""Geometry QA: real before/after Map.lua output, simulated native tracking dots."""
from pathlib import Path
import sys, os, zipfile
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.test-deps'))
from lupa.lua51 import LuaRuntime
from PIL import Image,ImageDraw,ImageFont
os.chdir(root)
setup="""
dofile('tests/wow.lua');fakeUI();A={}
for _,name in ipairs({'Store','Client','Resources','Selection'}) do assert(loadfile(name..'.lua'))('Gatherly',A) end
"""
scene="""
A.db=A.Store.Open();A.Resources.Settings(A.db.settings).mini=false
A.Client.Position=function() return {mapID=1,x=.5,y=.5} end
A.Client.Size=function() return 1000,500 end
C_Minimap={GetViewRadius=function() return 160 end};GetCVar=function() return '0' end
Minimap:SetSize(192,192)
LibStub=function() return {AddWorldMapIconMap=function() end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
local points={{mapID=1,x=.36,y=.56},{mapID=1,x=.64,y=.52},{mapID=1,x=.60,y=.72},{mapID=1,x=.36,y=.72}}
nativeNodes={{mapID=1,x=.57,y=.51},{mapID=1,x=.5,y=.54},points[2],points[3]}
for _,p in ipairs(nativeNodes) do p.kind='herb';p.materialID='gm:herb:401';p.name='Peacebloom';p.source='imported';A.Store.Observe(A.db,p) end
A.Map.Refresh(A.db,{mapID=1,points=points,loop=true},{Snapshot=function() return {status='running',index=2,target=points[2],visited={}} end})
"""
with zipfile.ZipFile(root/'dist/Gatherly-0.5.0.zip') as archive:
    before=archive.read('Gatherly/Map.lua').decode()
after=(root/'Map.lua').read_text()
image=Image.new('RGBA',(1000,520),'#141410');d=ImageDraw.Draw(image)
font=lambda size:ImageFont.truetype('C:/Windows/Fonts/arial.ttf',size)
d.text((34,18),'Tracking visibility: minimap route geometry',font=font(22),fill='#efd9a0')
d.text((34,50),'Real Lua line output; simulated terrain and tracking dots. Displayed at 2x scale.',font=font(13),fill='#b4ad98')
for index,(title,source) in enumerate([('Before: opaque route',before),('After: thin lines with clear gaps',after)]):
    lua=LuaRuntime(unpack_returned_tuples=True);lua.execute(setup);lua.execute(source,'Gatherly',lua.globals().A);lua.execute(scene)
    cx,cy=250+index*500,294
    d.text((cx-190,80),title,font=font(18),fill='#f2cf72')
    d.ellipse((cx-193,cy-193,cx+193,cy+193),fill='#222219',outline='#81764f',width=5)
    terrain=Image.new('RGBA',image.size);td=ImageDraw.Draw(terrain)
    td.ellipse((cx-186,cy-186,cx+186,cy+186),fill='#354125')
    for y in range(cy-150,cy+180,42):
        td.arc((cx-175,y-140,cx+145,y+130),190,325,fill='#505535',width=2)
    mask=Image.new('L',image.size);ImageDraw.Draw(mask).ellipse((cx-186,cy-186,cx+186,cy+186),fill=255)
    image.paste(terrain,(0,0),mask);d=ImageDraw.Draw(image)
    def xy(x,y):return cx+x*2,cy-y*2
    for node in lua.globals().nativeNodes.values():
        x,y=xy((node['x']-.5)*600,(.5-node['y'])*300)
        d.ellipse((x-6,y-6,x+6,y+6),fill='#171a0b')
        d.ellipse((x-4,y-4,x+4,y+4),fill='#ffea30')
    for line in lua.globals().A.Map.miniLines.values():
        if not line['shown']:continue
        a,b=line['lineStart'],line['lineEnd'];color=list(line['color'].values())
        overlay=Image.new('RGBA',image.size)
        ImageDraw.Draw(overlay).line([xy(a[3],a[4]),xy(b[3],b[4])],fill=tuple(round(v*255) for v in color),width=max(1,round(line['thickness']*2)))
        image=Image.alpha_composite(image,overlay);d=ImageDraw.Draw(image)
    target=lua.globals().A.Map.byKey['m:point:2'];x,y=xy(84,-6)
    if target['icon']['shown']:
        d.polygon([(x,y-14),(x-13,y+11),(x+13,y+11)],fill='#d6a52a')
    else:d.ellipse((x-20,y-20,x+20,y+20),outline='#e8bd45',width=3)
    d.polygon([(cx,cy-12),(cx-8,cy+8),(cx,cy+3),(cx+8,cy+8)],fill='#f0ede0',outline='#191b13')
d.text((34,498),'Known spawns receive gaps; unrecorded dots may still cross a visible line. Minimap route lines can be hidden.',font=font(12),fill='#b4ad98')
path=root/'docs/previews/tracking-clearance.png';image.convert('RGB').save(path);print(path)
