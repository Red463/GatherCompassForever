local function setup()
 dofile('tests/wow.lua'); fakeUI(); UIParent:SetSize(1920,1080)
 local A={}; for _,m in ipairs({'Store','Client','Editor','Recorder','Planner','Follower'}) do module(m,A) end
 moduleUI(A); A.db=A.Store.Open(); A.Client.Position=function() return point(.1) end; A.Client.Distance=distance; A.Client.Size=function() return 1000,500 end; A.Store.distance=distance
 A.UI.Build(); A.UI.OpenRoutes(); return A
end

test('node opacity sliders update markers live without changing unrelated opacity settings',function()
 local A=setup();module('Map',A);local U=A.UI;U.SetTab('nodes')
 local count=0;local refresh=A.Map.Refresh;A.Map.Refresh=function(...) count=count+1;return refresh(...) end
 for _,entry in ipairs({{'nodeWorldOpacity','worldIconOpacity',25},{'nodeMiniIconOpacity','miniIconOpacity',50},{'nodeOutlineOpacity','miniOutlineOpacity',75}}) do
  local slider=U.controls[entry[1]];assert(slider and slider.kind=='Slider')
  local lo,hi=slider:GetMinMaxValues();eq(lo,0);eq(hi,100)
  slider.scripts.OnValueChanged(slider,entry[3]);eq(A.Resources.Settings(A.db.settings)[entry[2]],entry[3]/100)
 end
 eq(count,3);U.Refresh();eq(count,3)
 U.syncingOptions=true;U.controls.nodeWorldOpacity.scripts.OnValueChanged(U.controls.nodeWorldOpacity,0);U.syncingOptions=false
 eq(A.Resources.Settings(A.db.settings).worldIconOpacity,.25);eq(count,3)
 U.controls.nodeWorldOpacity.scripts.OnValueChanged(U.controls.nodeWorldOpacity,0/0);eq(count,3)
 eq(U.nodeOpacityLabels.nodeWorldOpacity:GetText(),'World-map icons: 25%')
end)

test('changing Gathering immediately refreshes both maps and clears an older resource focus',function()
 local A=setup();module('Map',A);local U=A.UI;local count=0
 local herb=A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='herb',source='imported'})
 local ore=A.Store.Observe(A.db,{mapID=1,x=.4,y=.5,kind='ore',materialID='ore',source='imported'})
 LibStub=function() return {AddWorldMapIconMap=function() end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
 local refresh=A.Map.Refresh;A.Map.Refresh=function(...) count=count+1;return refresh(...) end
 A.Map.SetNodeFocus(1,{herb=true},herb.key)
 U.SetKind('ore');eq(count,1);eq(A.Map.nodeFocus,nil)
 assert(A.Map.byKey['w:node:'..ore.key]);eq(A.Map.byKey['w:node:'..herb.key],nil)
 assert(A.Map.byKey['m:node:'..ore.key]);eq(A.Map.byKey['m:node:'..herb.key],nil)
 LibStub=nil
end)
test('completed route does not label or colour a newly selected route',function()
 local A=setup(); local U=A.UI
 local a=A.Store.SaveRoute(A.db,{mapID=1,name='A',points={point(.2),point(.3)}})
 local b=A.Store.SaveRoute(A.db,{mapID=1,name='B',points={point(.4),point(.5)}})
 U.SelectRoute(a); U.controls.start.scripts.OnClick(); U.OpenRoutes(); A.follower:Skip(); A.follower:Skip(); U.SelectRoute(b)
 eq(U.footerName:GetText(),'B'); eq(A.follower,nil)
end)
test('hidden and compact refresh avoid full surface population',function()
 local A=setup(); local calls=0; local original=A.Store.Select
 A.Store.Select=function(...) calls=calls+1; return original(...) end
 A.UI.frame:Hide(); A.UI.Refresh(); eq(calls,0)
 A.UI.frame:Show(); A.UI.SetCompact(true); calls=0; A.UI.Refresh(); assert(calls<=1,'Compact refresh scanned nodes '..calls..' times')
end)
test('arrow matches the skin and route review offers world map access',function()
 local A=setup(); module('Arrow',A); A.Arrow.Build()
 near(A.Arrow.frame.label.textColor[1],A.Skin.gold[1]); assert(A.Arrow.frame:GetWidth()<=160)
 assert(A.UI.controls.map); A.UI.controls.map.scripts.OnClick()
end)
test('preferences persist independently of route review',function()
 local A=setup();local U=A.UI
 U.controls.arrival.scripts.OnValueChanged(U.controls.arrival,20); eq(A.db.settings.arrival,20)
 U.controls.arrowScale.scripts.OnValueChanged(U.controls.arrowScale,1.2); assert(A.db.settings.arrowScale>1)
 U.controls.resetArrow.scripts.OnClick(); eq(A.db.settings.arrowAnchor,nil); eq(A.db.settings.arrowScale,1)
end)
test('route sketch reuses bounded visuals and clears on empty selection',function()
 local A=setup(); local sketch=A.RouteSketch.New(UIParent); sketch.frame:SetSize(300,160)
 local pts={}; for i=1,1000 do pts[i]=point(i/1001,math.sin(i/100)*.2+.5) end
 local r={mapID=1,points=pts,loop=true}; sketch:Draw(r,500); assert(#sketch.lines<=257)
 local first=sketch.lines[1]; sketch:Draw(r,500); eq(sketch.lines[1],first)
 sketch:Draw(nil); for _,line in ipairs(sketch.lines) do eq(line:IsShown(),false) end
end)
test('route sketch invalidates for coordinate changes with equal weighted sums',function()
 local A=setup(); local s=A.RouteSketch.New(UIParent); s.frame:SetSize(300,160)
 local r={mapID=1,points={point(.1,.1),point(.3,.5),point(.9,.9)}}; s:Draw(r,2); local key=s.key
 r.points[2]=point(.67,.37); s:Draw(r,2); assert(s.key~=key)
end)

test('successful navigation hides the panel and arrow click reopens without changing follower',function()
 local A=setup();module('Arrow',A);local U=A.UI
 A.selectedRoute=A.Store.SaveRoute(A.db,{name='Trail',mapID=1,points={point(.4),point(.6)}})
 U.controls.start.scripts.OnClick();eq(U.frame:IsShown(),false);local f=A.follower;assert(f)
 A.Arrow.Update(point(.1),0,f:Target(),distance,f:Snapshot())
 local arrow=A.Arrow.frame;eq(arrow:IsShown(),true)
 arrow.scripts.OnMouseDown(arrow,'LeftButton');arrow.scripts.OnMouseUp(arrow,'LeftButton')
 eq(U.frame:IsShown(),true);eq(U.tab,'routes');eq(U.compact,false);eq(A.follower,f)
 U.frame:Hide();arrow.scripts.OnMouseDown(arrow,'LeftButton');arrow.scripts.OnDragStart(arrow);arrow.scripts.OnDragStop(arrow);arrow.scripts.OnMouseUp(arrow,'LeftButton')
 eq(U.frame:IsShown(),false)
 U.OpenRoutes();A.selectedRoute=nil;U.controls.start.scripts.OnClick();eq(U.frame:IsShown(),true)
end)
test('paused and unavailable navigation retain a clickable frame without a stale direction',function()
 local A=setup();module('Arrow',A);A.selectedRoute=A.Store.SaveRoute(A.db,{name='Trail',mapID=1,points={point(.4)}})
 A.UI.controls.start.scripts.OnClick();A.follower:Pause()
 A.Arrow.Update(nil,nil,A.follower:Target(),distance,A.follower:Snapshot());eq(A.Arrow.frame:IsShown(),true);eq(A.Arrow.frame.icon:IsShown(),false);eq(A.Arrow.frame.label:GetText(),'Paused')
 A.follower:Resume();A.Arrow.Update(nil,nil,A.follower:Target(),distance,A.follower:Snapshot());eq(A.Arrow.frame:IsShown(),true);eq(A.Arrow.frame.icon:IsShown(),false)
 A.Arrow.Update(nil,nil,nil,distance,nil);eq(A.Arrow.frame:IsShown(),false)
end)
test('node display controls persist settings and keep at least one marker layer',function()
 local A=setup();local U=A.UI;U.SetTab('nodes');assert(U.nodeOptions:IsShown())
 local s=A.Resources.Settings(A.db.settings);U.controls.nodeWorld.scripts.OnClick();eq(s.world,false)
 U.controls.nodeOutline:SelectValue('square');eq(s.outline,'square')
 U.controls.nodeOutline:SelectValue('none');eq(s.outline,'none')
 U.controls.nodeIcon.scripts.OnClick();eq(s.icon,true)
 U.controls.nodeDistance:SelectValue(30);eq(s.hideDistance,30)
 U.controls.nodeRouteLine.scripts.OnClick();eq(s.routeLines,false);eq(U.controls.nodeRouteLine:GetChecked(),false)
 U.controls.nodeOutline:SelectValue('ring');U.controls.nodeOutlineSize:SelectValue(28);eq(s.outlineSize,28)
 U.controls.nodeIconSize:SelectValue(16);eq(s.iconSize,16)
end)
test('material choices include an icon and checkbox while preserving material identity',function()
 local A=setup();A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 A.UI.Refresh();local row=A.UI.materialRows[1];assert(row.icon.texture);assert(row.check:IsShown());eq(row.materialID,'gm:herb:401')
 row.scripts.OnClick(row);eq(row.check:IsShown(),false);eq(#A.UI.SelectedNodes(),0)
end)

test('arrow progress follows current waypoint and one-based laps without changing navigation',function()
 local A=setup();module('Arrow',A)
 local route={mapID=1,name='Loop',loop=true,points={point(.1),point(.3),point(.5)}}
 local f=A.Follower.New(route,point(.31),distance);A.follower=f
 local function draw() A.Arrow.Update(point(.31),0,f:Target(),distance,f:Snapshot()) end
 draw();eq(A.Arrow.frame.progress:GetText(),'2/3 - Lap 1');eq(A.Arrow.frame:GetHeight(),104)
 A.UI.Refresh();assert(A.UI.footerMeta:GetText():find('Lap 1',1,true),'Panel lap must match arrow lap')
 f:Skip();draw();eq(A.Arrow.frame.progress:GetText(),'3/3 - Lap 1')
 f:Skip();draw();eq(A.Arrow.frame.progress:GetText(),'1/3 - Lap 1')
 f:Reverse();f:Skip();draw();eq(A.Arrow.frame.progress:GetText(),'3/3 - Lap 1')
 f:Pause();A.Arrow.Update(nil,nil,f:Target(),distance,f:Snapshot());eq(A.Arrow.frame.progress:GetText(),'3/3 - Lap 1');eq(A.Arrow.frame.label:GetText(),'Paused')
end)
test('arrow progress preference immediately hides counters and persists across a saved-data reopen',function()
 local A=setup();module('Arrow',A)
 local f=A.Follower.New({mapID=1,loop=true,points={point(.2),point(.4)}},point(.1),distance);A.follower=f
 A.Arrow.Update(point(.1),0,f:Target(),distance,f:Snapshot());eq(A.Arrow.frame.progress:IsShown(),true)
 A.UI.SetTab('settings');A.UI.controls.arrowProgress.scripts.OnClick()
 eq(A.db.settings.arrowProgress,false);eq(A.Arrow.frame.progress:IsShown(),false);eq(A.Arrow.frame:GetHeight(),84)
 A.db=A.Store.Open(A.Store.Copy(A.db));module('Arrow',A)
 A.Arrow.Update(point(.1),0,f:Target(),distance,f:Snapshot());eq(A.Arrow.frame.progress:IsShown(),false)
 A.UI.controls.arrowProgress.scripts.OnClick();eq(A.db.settings.arrowProgress,true);eq(A.Arrow.frame.progress:IsShown(),true);eq(A.Arrow.frame:GetHeight(),104)
 eq(A.follower,f);eq(f.index,1);eq(f.lap,0)
end)
test('one-way arrow reports only current step and missing metadata keeps the compact layout',function()
 local A=setup();module('Arrow',A)
 local f=A.Follower.New({mapID=1,loop=false,points={point(.2),point(.4)}},point(.1),distance)
 A.Arrow.Update(point(.1),0,f:Target(),distance,f:Snapshot());eq(A.Arrow.frame.progress:GetText(),'1/2')
 A.Arrow.Update(point(.1),0,f:Target(),distance,nil);eq(A.Arrow.frame.progress:IsShown(),false);eq(A.Arrow.frame:GetHeight(),84)
end)

test('Classic window has native chrome compact header bottom tabs and standard option controls',function()
 local A=setup();local U=A.UI
 eq(U.chrome.template,'PortraitFrameTemplate');assert(U.header:GetHeight()<=64);assert(U.frame:GetHeight()<650)
 eq(U.tabs.routes.template,'PanelTopTabButtonTemplate')
 eq(U.controls.arrival.kind,'Slider');eq(U.controls.arrowScale.kind,'Slider');eq(U.controls.arrowProgress.kind,'CheckButton')
 eq(U.controls.arrival.mouse,true);eq(U.controls.arrowScale.mouse,true)
 assert(U.controls.close:GetFrameLevel()>U.header:GetFrameLevel(),'Close button must receive clicks above the drag header')
 U.controls.arrival.scripts.OnValueChanged(U.controls.arrival,35);eq(A.db.settings.arrival,35)
 U.controls.arrowScale.scripts.OnValueChanged(U.controls.arrowScale,.8);near(A.db.settings.arrowScale,.8)
 U.controls.arrowProgress.scripts.OnClick();eq(A.db.settings.arrowProgress,false)
 U.SetCompact(true);eq(U.chrome:IsShown(),false);U.SetCompact(false);eq(U.chrome:IsShown(),true)
end)

test('native close button stays above the overlapping drag header',function()
 local U=setup().UI
 assert(U.controls.close:GetFrameLevel()>U.header:GetFrameLevel(),'Drag header intercepts close-button clicks')
end)

test('floating arrow has no dialog frame or permanent help and exposes destination on hover',function()
 local A=setup();module('Arrow',A);local target=point(.4);target.name='Silverleaf'
 A.Arrow.Update(point(.1),0,target,distance,{index=7,total=32,loop=true,lap=1,status='running'})
 local f=A.Arrow.frame;eq(f.template,nil);eq(f.backdrop,nil);eq(f.opaqueBase,nil)
 eq(f.hint,nil);eq(f.detail,nil);eq(f:GetWidth(),156);eq(f.icon:GetWidth(),56)
 eq(f.progress:GetText(),'7/32 - Lap 2');assert(A.Arrow.TooltipText():find('Silverleaf',1,true));assert(A.Arrow.TooltipText():find('Left-click',1,true))
 eq(f.stateGlyph:IsShown(),false);eq(f.shadow:IsShown(),true)
end)
test('floating arrow status stays clickable and restores direction cleanly after pause or lost position',function()
 local A=setup();module('Arrow',A);local target=point(.4)
 A.Arrow.Update(nil,nil,target,distance,{index=1,total=3,lap=0,loop=true,status='paused'})
 local f=A.Arrow.frame;eq(f.stateGlyph:GetText(),'II');eq(f.stateGlyph:IsShown(),true);eq(f.shadow:IsShown(),false)
 eq(f.label:GetText(),'Paused');assert(A.Arrow.TooltipText():find('resume',1,true))
 A.Arrow.Update(nil,nil,target,distance,{index=1,total=3,loop=true,status='suspended'})
 eq(f.stateGlyph:GetText(),'?');eq(f.label:GetText(),'No direction');eq(f.icon:IsShown(),false)
 A.Arrow.Update(point(.1),0,target,distance,{index=1,total=3,loop=true,status='running'})
 eq(f.stateGlyph:IsShown(),false);eq(f.icon:IsShown(),true);eq(f.shadow:IsShown(),true);eq(f.label:GetText(),'300 yd')
end)

test('top tabs and gathering checkboxes apply real filters and close open menus',function()
 local A=setup();local U=A.UI
 assert(U.nav.topTabs);assert(U.nav:GetFrameLevel()>U.header:GetFrameLevel())
 U.controls.sourceImported.scripts.OnClick();eq(A.db.settings.source,'confirmed')
 U.controls.kindHerb.scripts.OnClick();eq(A.db.settings.kind,'ore')
 U.SetTab('nodes');U.controls.nodeOutline.scripts.OnClick(U.controls.nodeOutline);assert(A.Skin.dropdownMenu:IsShown())
 U.SetTab('settings');eq(A.Skin.dropdownMenu:IsShown(),false)
end)


test('next node preference applies immediately persists and escapes node text',function()
 local A=setup();module('Arrow',A);local target=point(.4);target.kind='gather';target.name='|cff00ff00Silverleaf|r'
 A.follower=A.Follower.New({mapID=1,points={target}},point(.1),distance)
 A.Arrow.Update(point(.1),0,A.follower:Target(),distance,A.follower:Snapshot());A.UI.SetTab('settings')
 assert(A.UI.controls.arrowNodeName);eq(A.UI.controls.arrowNodeName:GetChecked(),false)
 A.UI.controls.arrowNodeName.scripts.OnClick();eq(A.db.settings.arrowNodeName,true)
 eq(A.Arrow.frame.nodeName:IsShown(),true);eq(A.Arrow.frame.nodeName:GetText(),'||cff00ff00Silverleaf||r')
 A.db=A.Store.Open(A.Store.Copy(A.db));module('Arrow',A)
 A.Arrow.Update(point(.1),0,A.follower:Target(),distance,A.follower:Snapshot());eq(A.Arrow.frame.nodeName:IsShown(),true)
 A.UI.controls.arrowNodeName.scripts.OnClick();eq(A.db.settings.arrowNodeName,false);eq(A.Arrow.frame.nodeName:IsShown(),false)
end)
