"""Preview actual node OnEnter rows; Blizzard fonts/chrome are approximated."""
from pathlib import Path
import os, sys
root = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(root / '.test-deps'))
from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute(r"""
dofile('tests/wow.lua');fakeUI();A={}
for _,name in ipairs({'Store','Client','Resources','Map'}) do assert(loadfile(name..'.lua'))('Gatherly',A) end
A.db=A.Store.Open();A.Client.Position=function() return {mapID=1,x=.1,y=.5} end
A.Client.Size=function() return 1000,500 end;A.Client.Distance=function() return 30 end
A.Resources.Skills=function() return {herb=109},{herb={maxRank=150,bonus=0}} end
LibStub=function() return {AddWorldMapIconMap=function() end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
rows={}
GameTooltip.SetText=function(_,value,r,g,b) rows={{left=value,color={r or 1,g or 1,b or 1},heading=true}} end
GameTooltip.AddLine=function(_,value,r,g,b) rows[#rows+1]={left=value,color={r or 1,g or 1,b or 1}} end
GameTooltip.AddDoubleLine=function(_,left,right,lr,lg,lb,rr,rg,rb) rows[#rows+1]={left=left,right=right,color={lr,lg,lb},rightColor={rr,rg,rb}} end
local node=A.Store.Observe(A.db,{mapID=1,x=.13,y=.5,kind='herb',materialID='gm:herb:403',name='Earthroot',source='imported'})
A.Map.Refresh(A.db,nil);local pin=A.Map.byKey['m:node:'..node.key];pin.scripts.OnEnter(pin)
""")
rows = list(lua.globals().rows.values())
font = ImageFont.truetype('C:/Windows/Fonts/georgia.ttf', 16)
title = ImageFont.truetype('C:/Windows/Fonts/georgia.ttf', 19)
small = ImageFont.truetype('C:/Windows/Fonts/arial.ttf', 12)
image = Image.new('RGB', (800, 300), '#111c14');draw = ImageDraw.Draw(image)
draw.text((24, 18), 'NODE TOOLTIP / SIMULATED HERBALISM 109', font=small, fill='#abb8aa')
width = max(draw.textlength(row['left'], font=title if row['heading'] else font) + (draw.textlength(row['right'], font=font) + 52 if row['right'] else 0) for row in rows) + 32
height = len(rows) * 28 + 20
x,y = 24,50
draw.rounded_rectangle((x,y,x+width,y+height), radius=4, fill='#1a1b17', outline='#a59a80', width=2)
def color(value): return tuple(round(max(0,min(1,v))*255) for v in value.values())
for i,row in enumerate(rows):
    yy = y+11+i*28
    draw.text((x+14,yy), row['left'], font=title if row['heading'] else font, fill=color(row['color']))
    if row['right']:
        text=row['right'];draw.text((x+width-14-draw.textlength(text,font=font),yy),text,font=font,fill=color(row['rightColor']))
draw.text((24, image.height-25), 'Rendered from addon Lua. Native Blizzard fonts and borders are approximated.', font=small, fill='#899785')
out=root/'docs/previews/node_skill_tooltip.png';image.save(out);print(out)
