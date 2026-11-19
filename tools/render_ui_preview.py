"""Non-client previews driven by the real Lua UI frame tree; substitutes fonts."""
from pathlib import Path
import json, math, os, sys
root=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(root/'.test-deps'))
from lupa.lua51 import LuaRuntime
from PIL import Image, ImageDraw, ImageFont, ImageChops
os.chdir(root)
out=root/'docs'/'previews';out.mkdir(parents=True,exist_ok=True)
CAPTURE=r'''
dofile('tests/wow.lua'); fakeUI(); UIParent:SetSize(1280,800); UIParent.captureID=0
captured={}; local original=CreateFrame
CreateFrame=function(...)
 local f=original(...); f.captureID=#captured+1; captured[#captured+1]=f; f.anchors={}
 f.SetPoint=function(self,...) local a={...}; if type(a[2])~='table' then a={a[1],self.parent,a[1],a[2] or 0,a[3] or 0} elseif type(a[3])~='string' then a={a[1],a[2],a[1],a[3] or 0,a[4] or 0} end; self.anchors[#self.anchors+1]=a end
 f.ClearAllPoints=function(self) self.anchors={};self.all=nil end
 f.SetAllPoints=function(self,target) self.all=target or self.parent end
 f.SetBackdrop=function(self,v) self.backdrop=v end
 f.SetBackdropColor=function(self,...) self.backColor={...} end
 f.SetBackdropBorderColor=function(self,...) self.borderColor={...} end
 f.SetFont=function(self,path,size,flags) self.fontPath=path;self.fontSize=size;self.fontFlags=flags end
 f.SetJustifyH=function(self,v) self.justify=v end
 f.SetJustifyV=function(self,v) self.justifyV=v end
 f.SetWordWrap=function(self,v) self.wrap=v end
 f.SetClipsChildren=function(self,v) self.clips=v end
 f.SetFrameStrata=function(self,v) self.strata=v end
 local makeTexture=f.CreateTexture
 f.CreateTexture=function(self,name,layer,template,sublevel) local t=makeTexture(self,name,layer,template,sublevel);t.drawLayer=layer;t.sublevel=sublevel;return t end
 local makeLine=f.CreateLine
 f.CreateLine=function(self,name,layer) local l=makeLine(self,name,layer);l.drawLayer=layer;return l end
 f.SetTexture=function(self,v) self.texture=v end
 f.SetTexCoord=function(self,...) self.crop={...} end
 f.SetStartPoint=function(self,...) self.lineStart={...} end
 f.SetEndPoint=function(self,...) self.lineEnd={...} end
 return f
end
WorldMapFrame:Hide()
A={};for _,m in ipairs({'Store','Client','Resources','MarkerGroups','SkillTooltip','Selection','Atlas','ResourceLibrary','DifficultyProbe','Editor','Recorder','Corridor','Planner','FarmingSession','Follower','Heatmap','MiniHeat','MinimapPins','Map','Skin','PanelWindow','ScrollPanel','VirtualList','Dropdown','Data/MapReveal','MapOverlays','MapArt','GroupPicker','RouteSketch','RouteView','ResourceLibraryView','UIActions','FilterSidebar','WelcomeView','MarkerFiltersView','NodeDisplayView','UI','Arrow','MinimapButton'}) do assert(loadfile(m..'.lua'))('GatherCompassForever',A) end
A.db=A.Store.Open();A.Client.Position=function() return {mapID=1,x=.2,y=.4} end
A.Client.Size=function() return 1000,600 end
A.Client.Distance=function(a,b) if not a or not b or a.mapID~=b.mapID then return end;return math.sqrt(((a.x-b.x)*1000)^2+((a.y-b.y)*600)^2) end
A.Client.Probe=function() return {loot=true,position=true,distance=true,facing=true,minimap=true} end
A.Store.distance=A.Client.Distance; C_Map={GetMapInfo=function(id) return {name=({[1]='Ashenvale',[2]='Darkshore',[3]='Elwynn Forest'})[id] or 'Zone '..tostring(id)} end}; C_Map.GetMapArtID=function() return 1 end;C_Map.GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=667,tileWidth=1000,tileHeight=667}} end;C_Map.GetMapArtLayerTextures=function() return {9001} end;A.UI.Build();A.UI.OpenRoutes()
function populate()
 local nodes={}
 for i=1,18 do local n=A.Store.Observe(A.db,{mapID=1,x=.18+(i%6)*.08,y=.18+math.floor(i/6)*.14,kind=i%3==0 and 'ore' or 'herb',name=i%3==0 and 'Copper vein' or i%2==0 and 'Silverleaf' or 'Peacebloom',materialID='m'..(i%3),source=i%2==0 and 'confirmed' or 'imported'});nodes[#nodes+1]=n end
 for i,name in ipairs({'Northern ridge circuit','Silverleaf along the river','Astranaar supply trail'}) do
  local points={};for j=1,10 do local n=nodes[(j+i)%#nodes+1];points[#points+1]={mapID=1,x=n.x,y=n.y,kind='gather',nodeKey=n.key} end
  local id=A.Store.SaveRoute(A.db,{name=name,mapID=1,loop=i~=3,points=points,recorded=i==3});if i==1 then A.selectedRoute=id end
 end
 A.UI.actions.generateReview()
end
function codexPopulate()
 A.Resources.Skills=function() return {herb=109,ore=70},{herb={maxRank=150,bonus=0},ore={maxRank=150,bonus=0}} end
 time=function() return 100000 end
 for i=1,8 do A.Store.Observe(A.db,{mapID=1,x=.22+i*.022,y=.4+i*.014,kind='herb',name='Earthroot',materialID='gm:herb:403',source=i%2==0 and 'confirmed' or 'imported',time=100000-i*180}) end
 for map=2,3 do for i=1,6 do A.Store.Observe(A.db,{mapID=map,x=.1+i*.07,y=.2+i*.02,kind='herb',name='Earthroot',materialID='gm:herb:403',source='imported'}) end end
 for i,name in ipairs({'Briarthorn','Mageroyal','Wild Steelbloom'}) do A.Store.Observe(A.db,{mapID=1,x=.4+i*.04,y=.5,kind='herb',name=name,materialID='node:herb:'..name,source='imported'}) end
 A.UI.SetTab('codex')
end
'''
map_art=Image.new('RGBA',(1000,667),'#a29460')
map_draw=ImageDraw.Draw(map_art)
for i in range(18):
    line=[(x,160+i*17+24*math.sin(x/90+i*.3)) for x in range(-20,1040,12)]
    map_draw.line(line,fill=(111+i%3*9,117+i%4*7,66,255),width=18)
map_draw.line([(560+50*math.sin(y/90),y) for y in range(0,668,5)],fill='#4b7770',width=20)
map_draw.line([(x,380+50*math.sin(x/230)) for x in range(0,1001,5)],fill='#716447',width=9)
map_draw.line([(x,380+50*math.sin(x/230)) for x in range(0,1001,5)],fill='#c1ae72',width=4)
map_draw.text((355,335),'ILLUSTRATIVE ZONE MAP',font=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',16),fill='#393d23')
fractions={'TOPLEFT':(0,0),'TOP':(.5,0),'TOPRIGHT':(1,0),'LEFT':(0,.5),'CENTER':(.5,.5),'RIGHT':(1,.5),'BOTTOMLEFT':(0,1),'BOTTOM':(.5,1),'BOTTOMRIGHT':(1,1)}
def vals(t): return list(t.values()) if t is not None else []
def rgba(t,default=(0,0,0,0)):
    if t is None:return default
    a=vals(t);return tuple(round(max(0,min(1,v))*255) for v in (a+[1])[:4])
def render(scene):
    lua=LuaRuntime(unpack_returned_tuples=True);lua.execute(CAPTURE)
    screen_w,screen_h=(1600,1080) if scene.endswith(('_wide','_tall')) else (1280,800)
    lua.execute(f'UIParent:SetSize({screen_w},{screen_h})')
    if scene not in ('empty','atlas_empty'):lua.execute('populate()')
    if scene.startswith('resources'):
        lua.execute("codexPopulate();A.UI.SetTab('resources')")
        if scene=='resources_herb':lua.execute("A.UI.resourceLibraryView.SetSearch('Earthroot');A.UI.resourceLibraryView.tiles[1].scripts.OnClick(A.UI.resourceLibraryView.tiles[1])")
        if scene=='resources_ore':lua.execute("A.Store.Observe(A.db,{mapID=1,x=.5,y=.5,kind='ore',name='Small Thorium Vein',materialID='gm:ore:214',source='imported'});A.Store.Observe(A.db,{mapID=2,x=.6,y=.5,kind='ore',name='Rich Thorium Vein',materialID='gm:ore:215',source='imported'});A.UI.resourceLibraryView.SetSearch('Thorium');A.UI.resourceLibraryView.tiles[1].scripts.OnClick(A.UI.resourceLibraryView.tiles[1])")
        if scene=='resources_zero':lua.execute("A.UI.resourceLibraryView.SetSearch('Black Lotus');A.UI.resourceLibraryView.tiles[1].scripts.OnClick(A.UI.resourceLibraryView.tiles[1])")
        if scene=='resources_search_empty':lua.execute("A.UI.resourceLibraryView.SetSearch('No matching resource')")
        if scene=='resources_page2':lua.execute("A.UI.controls.resourceNext.scripts.OnClick()")
        if scene=='resources_restored_preferences':lua.execute("A.UI.SetTab('settings')")
    if scene=='mini_heat':
        lua.execute("A.UI.actions.generateStart();A.db.settings.routeStyle='heatmap';A.Resources.Settings(A.db.settings).mini=false;Minimap=CreateFrame('Frame',nil,UIParent);Minimap:SetSize(240,240);Minimap:SetPoint('TOPLEFT',UIParent,'TOPLEFT',520,-240);local terrain=Minimap:CreateTexture(nil,'BACKGROUND');terrain:SetAllPoints();terrain:SetTexture(9001);C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end;GetMinimapShape=function() return 'SQUARE' end;A.Map.Refresh(A.db,A.follower.route,A.follower);local player=Minimap:CreateTexture(nil,'OVERLAY');player:SetPoint('CENTER',Minimap,'CENTER');player:SetSize(11,16);player:SetTexture('Interface\\\\AddOns\\\\GatherCompassForever\\\\Media\\\\GuideArrow');for _,n in ipairs(A.db.nodes[1]) do local x,y=A.Map.MiniProject(n,A.Client.Position(),1000,600,200,240,240,0);if x then local dot=Minimap:CreateTexture(nil,'OVERLAY');dot:SetColorTexture(1,.9,.1,1);dot:SetSize(4,4);dot:SetPoint('CENTER',Minimap,'CENTER',x,y) end end;local text=A.Skin.Label(UIParent,'Minimap heat with simulated native tracking dots',15,A.Skin.gold);text:SetPoint('TOPLEFT',UIParent,'TOPLEFT',400,-190);text:SetSize(500,30)")
    if scene=='minimap_button':
        lua.execute("A.UI.frame:Hide();Minimap=CreateFrame('Frame',nil,UIParent);Minimap:SetSize(180,180);Minimap:SetPoint('TOPLEFT',UIParent,'TOPLEFT',900,-100);Minimap:SetBackdropColor(.12,.16,.09,1);A.MinimapButton.Build()")
    if scene=='material_skills':
        lua.execute("A.Resources.Skills=function() return {herb=109},{herb={maxRank=150,bonus=0}} end;A.Store.Observe(A.db,{mapID=1,x=.5,y=.5,kind='herb',name='Earthroot',materialID='gm:herb:403',source='imported'});A.UI.SetKind('herb')")
    if scene in ('filters_scroll','filters_scroll_end'):
        lua.execute("for i,item in ipairs(A.Resources.Catalog()) do A.Store.Observe(A.db,{mapID=1,x=.1+i*.005,y=.5,kind=item.kind,name=item.name,materialID=item.materialID,source='imported'}) end;A.Resources.Skills=function() return {herb=109,ore=75},{herb={maxRank=150,bonus=0},ore={maxRank=150,bonus=0}} end;A.UI.Refresh()")
        if scene=='filters_scroll_end':lua.execute('A.UI.filterSidebar:SetOffset(A.UI.filterSidebar.maximum)')
    if scene=='groups':
        lua.execute("for _,id in ipairs({402,403}) do A.Store.Observe(A.db,{mapID=1,x=.34+(id-402)*.002,y=.3,kind='herb',materialID='gm:herb:'..id,name=id==402 and 'Silverleaf' or 'Earthroot',source='imported'}) end;A.UI.actions.generateReview();for _,pin in ipairs(A.UI.routeSketch.pins) do if pin.group and #pin.group.members>1 then pin.scripts.OnClick(pin);break end end")
    if scene=='route_heatmap':lua.execute("A.UI.controls.routeStyle:SelectValue('heatmap')")
    if scene=='route_selected':lua.execute("A.UI.routeSketch.pins[1].scripts.OnClick(A.UI.routeSketch.pins[1])")
    if scene=='compact':lua.execute('A.UI.controls.start.scripts.OnClick();A.UI.OpenRoutes();A.UI.SetCompact(true)')
    if scene=='preferences':lua.execute("A.UI.SetTab('settings')")
    if scene in ('welcome','welcome_importing'):
        lua.execute("A.UI.SetTab('welcome')")
        if scene=='welcome_importing':lua.execute("A.importJob=coroutine.create(function() end);A.status='Importing all zones: 1240 locations...';A.UI.Refresh()")
    if scene in ('nodes','nodes_mini','dropdown'):lua.execute("A.UI.SetTab('nodes')")
    if scene in ('nodes_mini','dropdown'):lua.execute("A.UI.nodeDisplayView.SetPage('mini')")
    if scene=='dropdown':lua.execute("A.UI.controls.nodeDistance.scripts.OnClick(A.UI.controls.nodeDistance)")
    if scene in ('arrow_hidden_progress','arrow_paused','arrow_no_direction'):
        lua.execute("A.UI.controls.start.scripts.OnClick()")
        if scene=='arrow_hidden_progress':lua.execute('A.db.settings.arrowProgress=false')
        if scene=='arrow_paused':lua.execute('A.follower:Pause()')
        lua.execute("A.Arrow.Update("+('A.Client.Position(),0' if scene=='arrow_hidden_progress' else 'nil,nil')+",A.follower:Target(),A.Client.Distance,A.follower:Snapshot())")
    if scene in ('arrow_name','arrow_name_no_progress'):lua.execute('A.db.settings.arrowNodeName=true')
    if scene=='arrow_name_no_progress':lua.execute('A.db.settings.arrowProgress=false')
    if scene in ('arrow','arrow_name','arrow_name_no_progress'):lua.execute("A.UI.controls.start.scripts.OnClick();A.Arrow.Update(A.Client.Position(),0,A.follower:Target(),A.Client.Distance,A.follower:Snapshot())")
    if scene.startswith('resize_'):
        size={'min':(860,600),'wide':(1400,900),'tall':(960,900)}[scene.split('_')[-1]]
        lua.execute(f'A.UI.window:Resize({size[0]},{size[1]})')
    if scene in ('codex_min','codex_wide','nodes_min','welcome_min','preferences_min'):
        lua.execute('A.UI.window:Resize('+('1400,900' if scene.endswith('wide') else '860,600')+')')
        if scene.startswith('codex'):lua.execute("codexPopulate();A.UI.SetTab('codex')")
        if scene.startswith('nodes'):lua.execute("A.UI.SetTab('nodes');A.UI.nodeDisplayView.SetPage('mini')")
        if scene.startswith('welcome'):lua.execute("A.UI.SetTab('welcome')")
        if scene.startswith('preferences'):lua.execute("A.UI.SetTab('settings');A.UI.preferencesScroll:SetOffset(10000)")
    objects=vals(lua.globals().captured);byid={int(o['captureID']):o for o in objects}; boxes={0:(0,0,screen_w,screen_h)};resolving=set()
    def ident(o):return int(o['captureID']) if o and o['captureID'] is not None else 0
    def box(o):
        k=ident(o)
        if k in boxes:return boxes[k]
        if k in resolving:raise ValueError('Anchor cycle')
        resolving.add(k)
        if o['all'] is not None:r=box(o['all'])
        else:
            w,h=o['width'],o['height']; anchors=vals(o['anchors']);constraints=[]
            for a in anchors:
                own,target,rel,dx,dy=a[1],a[2],a[3],a[4] or 0,a[5] or 0
                tx,ty,tw,th=box(target);fx,fy=fractions.get(rel,(0,0));ox,oy=fractions.get(own,(0,0))
                constraints.append((ox,oy,tx+tw*fx+dx,ty+th*fy-dy))
            for a in constraints:
                for b in constraints:
                    if w is None and a[0]!=b[0]:w=(b[2]-a[2])/(b[0]-a[0])
                    if h is None and a[1]!=b[1]:h=(b[3]-a[3])/(b[1]-a[1])
            w=w if w is not None else 0;h=h if h is not None else (o['fontSize'] or 12)+4
            if constraints:a=constraints[0];x,y=a[2]-w*a[0],a[3]-h*a[1]
            else:x,y,_,_=box(o['parent'])
            r=(x,y,w,h)
        if o['scrollOwner'] is not None:r=(r[0],r[1]-(o['scrollOwner']['verticalScroll'] or 0),r[2],r[3])
        resolving.remove(k);boxes[k]=r;return r
    def visible(o):return o['shown'] is not False and (o['parent'] is None or ident(o['parent'])==0 or visible(o['parent']))
    im=Image.new('RGBA',(screen_w,screen_h),'#0c1711');d=ImageDraw.Draw(im)
    d.text((160,27),'GATHER COMPASS FOREVER 0.12.0 / '+scene.upper()+' / ACTUAL LUA LAYOUT PREVIEW',font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',11),fill='#9cae9d')
    fonts={}; text_report=[]
    def font(o):
        size=int(o['fontSize'] or 12);family='georgia.ttf' if 'FRIZ' in (o['fontPath'] or '') else 'arial.ttf';key=(family,size)
        if key not in fonts:fonts[key]=ImageFont.truetype('C:/Windows/Fonts/'+family,size)
        return fonts[key]
    strata_order={'BACKGROUND':0,'LOW':1,'MEDIUM':2,'HIGH':3,'DIALOG':4,'FULLSCREEN':5,'FULLSCREEN_DIALOG':6,'TOOLTIP':7}
    def draw_order(o):
        p=o;strata='MEDIUM'
        while p is not None:
            if p['strata'] is not None:strata=p['strata'];break
            p=p['parent']
        region=o['kind'] in ('Texture','Line','FontString')
        level=o['parent'].GetFrameLevel(o['parent']) if region and o['parent'] is not None else o.GetFrameLevel(o)
        layer=o['drawLayer'] or ('OVERLAY' if o['kind']=='FontString' else 'ARTWORK')
        return strata_order.get(strata,2),level,({'BACKGROUND':0,'BORDER':1,'ARTWORK':2,'OVERLAY':3,'HIGHLIGHT':4}.get(layer,0) if region else -1),o['sublevel'] or 0,ident(o)
    for o in sorted(objects,key=draw_order):
        if not visible(o) or o['kind']=='MaskTexture':continue
        x,y,w,h=box(o)
        if o['kind']=='Line' and o['lineStart'] is not None:
            def endpoint(a):
                tx,ty,tw,th=box(a[2]);fx,fy=fractions[a[1]];return tx+tw*fx+(a[3] or 0),ty+th*fy-(a[4] or 0)
            a,b=endpoint(o['lineStart']),endpoint(o['lineEnd']);x,y=min(a[0],b[0]),min(a[1],b[1]);w,h=max(1,abs(b[0]-a[0])),max(1,abs(b[1]-a[1]))
        rect=(round(x),round(y),round(x+w),round(y+h))
        if w<0 or h<0:raise AssertionError('Negative geometry')
        if o['parent'] is not None and ident(o['parent']['opaqueBase'])==ident(o):continue
        clipping=None;ancestor=o['parent']
        while ancestor is not None and ident(ancestor)!=0:
            if ancestor['kind']=='ScrollFrame' or ancestor['clips']:
                ax,ay,aw,ah=box(ancestor);clipping=(round(ax),round(ay),round(ax+aw),round(ay+ah))
                break
            ancestor=ancestor['parent']
        if clipping and (rect[2]<=clipping[0] or rect[0]>=clipping[2] or rect[3]<=clipping[1] or rect[1]>=clipping[3]):continue
        before=im.copy() if clipping and (rect[0]<clipping[0] or rect[1]<clipping[1] or rect[2]>clipping[2] or rect[3]>clipping[3]) else None
        template=o['template'] or ''
        if o['normalTexture'] and 'SizeGrabber' in str(o['normalTexture']):
            for offset in (5,10,15):d.line([(x+w-offset,y+h-3),(x+w-3,y+h-offset)],fill='#b8a474',width=2)
        if template=='PortraitFrameTemplate':
            d.rectangle(rect,fill='#34322f',outline='#514d42',width=5)
            d.rectangle((x+5,y+5,x+w-5,y+h-5),outline='#a49a7d',width=2)
            d.rectangle((x+8,y+8,x+w-8,y+31),fill='#34291a',outline='#756248',width=2)
            d.ellipse((x-7,y-7,x+63,y+63),fill='#25251e',outline='#aaa18b',width=5)
            if o['title']:
                titlefont=ImageFont.truetype('C:/Windows/Fonts/georgia.ttf',16);tw=d.textlength(o['title'],font=titlefont)
                d.text((x+w/2-tw/2,y+6),o['title'],font=titlefont,fill='#ffd472')
        if template=='UIPanelButtonTemplate':
            disabled=o['enabled'] is False
            d.rectangle(rect,fill='#3b3831' if disabled else '#711b10',outline='#978362',width=2)
            d.line([(x+3,y+2),(x+w-3,y+2)],fill='#ad9673')
            d.line([(x+2,y+h-2),(x+w-2,y+h-2)],fill='#2c100b',width=2)
        if template in ('PanelTabButtonTemplate','PanelTopTabButtonTemplate'):
            d.polygon([(x+7,y+2),(x+w-7,y+2),(x+w-1,y+8),(x+w-3,y+h-2),(x+3,y+h-2),(x+1,y+8)],fill='#51422a' if o['selected'] else '#29241a',outline='#968366')
        if template=='UIPanelCloseButton':
            d.rectangle((x+5,y+5,x+w-5,y+h-5),fill='#7e1c14',outline='#a18b66',width=2)
            d.line([(x+11,y+10),(x+w-11,y+h-10)],fill='#ead3a0',width=2)
            d.line([(x+w-11,y+10),(x+11,y+h-10)],fill='#ead3a0',width=2)
        if o['kind']=='CheckButton':
            d.rectangle((x+3,y+3,x+w-3,y+h-3),fill='#17120d',outline='#aa8a4a',width=2)
            if o['checked']:d.line([(x+5,y+h*.5),(x+w*.42,y+h-5),(x+w-4,y+5)],fill='#f6db87',width=2)
        if o['kind']=='Slider':
            minimum,maximum=o['minimum'] or 0,o['maximum'] or 1
            value=o['value'] or minimum;fraction=max(0,min(1,(value-minimum)/(maximum-minimum))) if maximum>minimum else 0
            if o['orientation']=='VERTICAL':
                d.rectangle((x+3,y,x+w-3,y+h),fill='#0e0d0a',outline='#827456',width=2)
                ty=y+12+(h-24)*fraction;d.rectangle((x,ty-10,x+w,ty+10),fill='#958a70',outline='#d0bd91',width=2)
            else:
                d.rectangle((x,y+5,x+w,y+h-5),fill='#0e0d0a',outline='#827456',width=2)
                tx=x+8+(w-16)*fraction;d.rectangle((tx-6,y-3,tx+6,y+h+3),fill='#958a70',outline='#d0bd91',width=2)
        if o['backColor'] is not None:
            if o['backdrop'] is not None and 'UI-DialogBox-Background' in (o['backdrop']['bgFile'] or ''):
                d.rectangle(rect,fill='#171410',outline='#675b49',width=2)
            else:d.rectangle(rect,fill=rgba(o['backColor']),outline=rgba(o['borderColor']))
        if o['kind']!='Line' and o['color'] is not None and rgba(o['color'])[3]:
            colour=rgba(o['color'])
            if colour[3]<255 and w>0 and h>0:
                tile=Image.new('RGBA',(max(1,round(w)),max(1,round(h))),colour);im.alpha_composite(tile,(round(x),round(y)))
            else:d.rectangle(rect,fill=colour)
        texture=o['texture']
        if texture==9001 and w>0 and h>0:
            art=map_art.copy()
            if o['crop'] is not None:
                u=vals(o['crop']);art=art.crop((u[0]*art.width,u[2]*art.height,u[1]*art.width,u[3]*art.height))
            art=art.resize((max(1,round(w)),max(1,round(h))),Image.Resampling.LANCZOS);im.alpha_composite(art,(round(x),round(y)))
        if isinstance(texture,str) and '\\Media\\' in texture and w>0 and h>0:
            file=root/'Media'/(texture.split('\\')[-1]+'.tga'); art=Image.open(file).convert('RGBA')
            if o['crop'] is not None:
                u=vals(o['crop']);art=art.crop((u[0]*art.width,u[2]*art.height,u[1]*art.width,u[3]*art.height))
            if o['vertexColor'] is not None:art=ImageChops.multiply(art,Image.new('RGBA',art.size,rgba(o['vertexColor'])))
            if o['rotation'] is not None:art=art.rotate(math.degrees(o['rotation']),resample=Image.Resampling.BICUBIC)
            art=art.resize((max(1,round(w)),max(1,round(h))),Image.Resampling.LANCZOS);im.alpha_composite(art,(round(x),round(y)))
        if isinstance(texture,str) and w>0 and h>0 and '\\Media\\' not in texture:
            if 'UI-DialogBox-Background' in texture:d.rectangle(rect,fill='#211b15',outline='#65533a')
            elif 'UI-Panel-Button-' in texture:
                disabled='Disabled' in texture
                d.rectangle(rect,fill='#37322d' if disabled else '#611b13',outline='#8d7650',width=2)
                d.line([(x+2,y+2),(x+w-3,y+2)],fill='#776555' if disabled else '#c48a52')
            elif 'UI-ScrollBar-ScrollDownButton-Up' in texture:
                d.polygon([(x+w*.25,y+h*.35),(x+w*.75,y+h*.35),(x+w*.5,y+h*.65)],fill='#e8d4a0')
            elif 'UI-CheckBox-Up' in texture:d.rectangle((x+3,y+3,x+w-3,y+h-3),fill='#17120d',outline='#aa8a4a',width=2)
            elif 'UI-CheckBox-Check' in texture:d.line([(x+4,y+h*.5),(x+w*.42,y+h-5),(x+w-3,y+4)],fill='#f8d66a',width=2)
            elif 'UI-QuestTitleHighlight' in texture:pass
            elif 'MiniMap-TrackingBorder' in texture:
                d.ellipse((x+3,y+3,x+31,y+31),outline='#be9e5c',width=2)
            elif 'UI-Minimap-Background' in texture:
                d.ellipse(rect,fill='#171410')
            elif 'MinimapArrow' in texture:
                d.polygon([(x+w/2,y+2),(x+w-3,y+h-3),(x+w/2,y+h*.7),(x+3,y+h-3)],fill=rgba(o['vertexColor'],(243,206,104,255)))
            else:
                # Resource art is resolved from installed GatherMate2 when present;
                # otherwise a neutral preview tile stands for the native client icon.
                d.rectangle(rect,fill='#364325',outline='#9c8856'); d.ellipse((x+w*.28,y+h*.2,x+w*.72,y+h*.8),fill='#abc06b')
        if o['lineStart'] is not None:
            def linept(a):
                tx,ty,tw,th=box(a[2]);fx,fy=fractions[a[1]];return (tx+tw*fx+(a[3] or 0),ty+th*fy-(a[4] or 0))
            d.line([linept(o['lineStart']),linept(o['lineEnd'])],fill=rgba(o['color'],(190,175,115,255)),width=max(1,round(o['thickness'] or 2)))
        if o['kind'] in ('FontString','EditBox') and o['text'] and w>0:
            if o['kind']=='EditBox':x+=10;w-=20
            f=font(o); text=str(o['text']).replace('||','|');lines=[]
            for paragraph in text.split('\n'):
                if o['wrap']:
                    current=''
                    for word in paragraph.split():
                        new=(current+' '+word).strip()
                        if d.textlength(new,font=f)>w and current:lines.append(current);current=word
                        else:current=new
                    lines.append(current)
                else:
                    s=paragraph
                    if d.textlength(s,font=f)>w:
                        while s and d.textlength(s+'…',font=f)>w:s=s[:-1]
                        s+='…'
                    lines.append(s)
            step=(o['fontSize'] or 12)+2; maxlines=max(1,int(h//step)); lines=lines[:maxlines]
            ty=y+max(0,(h-len(lines)*step)/2)-1
            for s in lines:
                length=d.textlength(s,font=f);tx=x+(w-length)/2 if o['justify']=='CENTER' else x+w-length if o['justify']=='RIGHT' else x
                d.text((tx,ty),s,font=f,fill=rgba(o['textColor'],(220,225,210,255)),stroke_width=1 if 'OUTLINE' in (o['fontFlags'] or '') else 0,stroke_fill='#15120e');ty+=step
            text_report.append({'text':text,'box':[x,y,w,h]})
        if before is not None:
            mask=Image.new('L',im.size);ImageDraw.Draw(mask).rectangle(clipping,fill=255)
            im=Image.composite(im,before,mask);d=ImageDraw.Draw(im)
    d.text((160,screen_h-32),'Rendered from native Lua definitions. Native Blizzard textures and fonts are approximated; live Forever rendering still needs checking.',font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',11),fill='#839785')
    path=out/(scene+'.png');im.convert('RGB').save(path)
    (out/(scene+'.json')).write_text(json.dumps(text_report,indent=2),encoding='utf-8')
    print(path)
for scene in ['resize_min','resize_wide','resize_tall','codex_min','codex_wide','nodes_min','welcome_min','preferences_min','welcome','welcome_importing','filters_scroll','filters_scroll_end','library','route_heatmap','route_selected','groups','resources','resources_herb','resources_ore','resources_zero','resources_search_empty','resources_page2','resources_restored_preferences','minimap_button','mini_heat','material_skills','empty','compact','preferences','nodes','nodes_mini','arrow','arrow_name','arrow_name_no_progress','arrow_hidden_progress','arrow_paused','arrow_no_direction','dropdown']:render(scene)
