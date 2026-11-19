test('map projection respects non square geometry rotation and minimap clipping',function()
 local A={}; module('Store',A); module('Client',A); module('Map',A); module('Arrow',A)
 local x,y=A.Map.Project(point(.2,.3),1000,500); near(x,200); near(y,-150)
 x,y=A.Map.MiniProject(point(.6,.5),point(.5,.5),1000,500,200,200,200,0); near(x,50); near(y,0)
 x,y=A.Map.MiniProject(point(.5,.3),point(.5,.5),1000,500,200,200,200,math.pi/2); near(x,50); near(y,0)
 eq(A.Map.MiniProject(point(.9),point(.1),1000,500,100,200,200,0),nil)
 near(A.Arrow.Angle(point(.5,.4),point(.5,.5),1000,500,0),0)
 near(A.Arrow.Angle(point(.6,.5),point(.5,.5),1000,500,0),-math.pi/2)
end)

test('review heat replaces lines and stopping clears heat while keeping resource markers',function()
 dofile('tests/wow.lua');fakeUI();local A={};for _,name in ipairs({'Store','Client','Follower','Map'}) do module(name,A) end
 A.Client.Position=function() return point(.1) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance;A.Client.Facing=function() return 0 end
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end
 local db=A.Store.Open();db.settings.routeStyle='heatmap';local route={mapID=1,width=1000,height=500,points={point(.2),point(.3)},loop=true}
 A.plan={route=route,review=true};A.Map.Refresh(db,route,nil);assert(A.Map.worldHeat[1]:IsShown())
 eq(#A.Map.worldLines,0);local f=A.Follower.New(route,point(.1),distance);A.plan.review=false
 A.Map.Refresh(db,route,f);eq(#A.Map.miniLines,0);eq(A.Map.targetIndex,f.index)
 assert(A.Map.miniHeat[1] and A.Map.miniHeat[1]:IsShown())
 db.settings.routeStyle='lines';A.Map.Refresh(db,route,f);eq(A.Map.worldHeat[1]:IsShown(),false);assert(A.Map.worldLines[1]:IsShown())
 eq(A.Map.miniHeat[1]:IsShown(),false)
 db.settings.routeStyle='heatmap';A.Map.Refresh(db,route,f);WorldMapFrame:Hide();eq(A.Map.worldHeat[1]:IsVisible(),false)
 WorldMapFrame:Show();A.Map.Refresh(db,nil,nil);eq(A.Map.worldHeat[1]:IsShown(),false)
 C_Minimap=nil
end)

test('minimap heat respects overlay controls pause zone shape opacity and stop cleanup',function()
 dofile('tests/wow.lua');fakeUI();local A={};for _,n in ipairs({'Store','Client','Follower','Map'}) do module(n,A) end
 A.Client.Position=function() return point(.1) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance;A.Client.Facing=function() return 0 end
 GetCVar=function() return '0' end;C_Minimap={GetViewRadius=function() return 200 end};GetMinimapShape=function() return 'ROUND' end
 local db=A.Store.Open();db.settings.routeStyle='heatmap';local settings=A.Resources.Settings(db.settings);settings.mini=false
 local route={mapID=1,width=1000,height=500,points={point(.2),point(.3)},loop=true};local f=A.Follower.New(route,point(.1),distance)
 A.Map.Refresh(db,route,f);assert(A.Map.miniHeat[1]:IsShown());eq(A.Map.miniHeatLayer.mouse,false)
 f:Pause();A.Map.Refresh(db,route,f);assert(A.Map.miniHeat[1]:IsShown())
 settings.routeLines=false;A.Map.Refresh(db,route,f);eq(A.Map.miniHeat[1]:IsShown(),false)
 settings.routeLines=true;settings.routeOpacity=0;A.Map.Refresh(db,route,f);eq(A.Map.miniHeat[1]:IsShown(),false)
 settings.routeOpacity=.35;GetMinimapShape=function() return 'UNSUPPORTED' end;A.Map.Refresh(db,route,f);eq(A.Map.miniHeat[1]:IsShown(),false)
 GetMinimapShape=function() return 'ROUND' end;A.Map.Refresh(db,route,f);Minimap:Hide();eq(A.Map.miniHeat[1]:IsVisible(),false);Minimap:Show()
 A.Client.Position=function() return {mapID=2,x=.1,y=.5} end;A.Map.Refresh(db,route,f);eq(A.Map.miniHeat[1]:IsShown(),false)
 A.Client.Position=function() return point(.1) end;A.Map.Refresh(db,route,f);f:Stop();A.Map.Refresh(db,nil,f);eq(A.Map.miniHeat[1]:IsShown(),false)
 GetMinimapShape=nil;C_Minimap=nil
end)
test('browsing another saved route cannot draw an inactive world route',function()
 dofile('tests/wow.lua'); fakeUI(); local A={}; module('Store',A); module('Client',A); module('Map',A)
 A.Client.Position=function() return point(.1) end; A.Client.Size=function() return 1000,500 end
 WorldMapFrame.GetMapID=function() return 2 end
 A.mapPreviewRoute={mapID=2,points={{mapID=2,x=.1,y=.2},{mapID=2,x=.3,y=.4}}}
 A.Map.Refresh(A.Store.Open(),{mapID=1,points={point(.1),point(.2)}})
 for _,line in ipairs(A.Map.worldLines) do eq(line:IsShown(),false) end
end)
test('world map shows the viewed zone while minimap retains the player zone',function()
 dofile('tests/wow.lua'); fakeUI(); local A={}; module('Store',A); module('Client',A); module('Map',A)
 A.Store.distance=distance; A.Client.Position=function() return point(.1) end; A.Client.Size=function() return 1000,500 end
 WorldMapFrame.GetMapID=function() return 2 end
 local db=A.Store.Open()
 for map=1,2 do A.Store.Observe(db,{mapID=map,x=.3,y=.3,kind='herb',name='Herb',materialID='herb',source='confirmed'}) end
 local world,mini={},{}
 LibStub=function(name) if name=='HereBeDragons-Pins-2.0' then return {
  AddWorldMapIconMap=function(_,_,_,map) world[map]=true end,AddMinimapIconMap=function(_,_,_,map) mini[map]=true end,
  RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end end
 A.Map.Refresh(db,nil); eq(world[2],true); eq(mini[1],true); LibStub=nil
end)
test('rotating minimap never falls back to north up when facing is unavailable',function()
 dofile('tests/wow.lua'); fakeUI(); local A={}; module('Store',A); module('Client',A); module('Map',A)
 A.Client.Position=function() return point(.5) end; A.Client.Size=function() return 1000,500 end
 A.Client.Facing=function() return nil end; GetCVar=function() return '1' end; C_Minimap={GetViewRadius=function() return 200 end}
 A.Map.Refresh(A.Store.Open(),{mapID=1,points={point(.5),point(.6)}})
 for _,line in ipairs(A.Map.miniLines) do eq(line:IsShown(),false) end
 GetCVar=nil; C_Minimap=nil
end)
test('map retains active drag button and renders selected decimated editor point',function()
 dofile('tests/wow.lua'); fakeUI(); local A={}; module('Store',A); module('Client',A); module('Editor',A); module('Map',A)
 A.Client.Position=function() return point(.1) end; A.Client.Size=function() return 1000,500 end
 local removed=0; local registered={}
 local lib={RemoveAllWorldMapIcons=function() removed=removed+1 end,RemoveAllMinimapIcons=function() removed=removed+1 end,
  AddWorldMapIconMap=function(_,_,f) registered[f]=true end,AddMinimapIconMap=function(_,_,f) registered[f]=true end,
  RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end}
 LibStub=function(name) if name=='HereBeDragons-Pins-2.0' then return lib end end
 local points={}; for i=1,201 do points[i]=point(i/1000) end
 local e=A.Editor.New({mapID=1,name='Long',points=points}); A.Map.SetEditor(e); A.editIndex=2
 local db=A.Store.Open(); A.Map.Refresh(db,e.draft)
 local selected; for _,p in ipairs(A.Map.pins) do if p.index==2 and p:IsShown() then selected=p end end
 assert(selected,'Selected point needs a draggable marker')
 selected.scripts.OnDragStart(selected); A.Map.Refresh(db,e.draft); A.Map.Refresh(db,e.draft)
 eq(removed,0);eq(selected:GetParent(),A.Map.editLayer);eq(A.Map.dragIndex,2)
 selected.scripts.OnDragStop(selected); eq(A.Map.dragIndex,nil); LibStub=nil
end)
test('map only adds points in active editor and dragging moves the draft',function()
 dofile('tests/wow.lua'); fakeUI(); local A={}; module('Store',A); module('Client',A); module('Editor',A); module('Map',A)
 A.Client.Position=function() return point(.1) end; A.Client.Size=function() return 1000,500 end
 eq(A.Map.AddAtCursor(),false)
 local e=A.Editor.New({name='Map',mapID=1,points={}}); A.Map.SetEditor(e); eq(A.Map.AddAtCursor(),true); eq(#e:Route().points,1)
 A.Map.MoveAtCursor(1); near(e:Route().points[1].x,.25); near(e:Route().points[1].y,.4)
 A.Map.SetEditor(nil); eq(A.Map.AddAtCursor(),false)
end)

local function markerSetup()
 dofile('tests/wow.lua'); fakeUI();local A={}; module('Store',A);module('Client',A);module('Map',A)
 A.Client.Position=function() return point(.1) end;A.Client.Distance=distance
 A.Resources.Skills=function() return {herb=25} end
 LibStub=function() return {AddWorldMapIconMap=function() end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
 A.db=A.Store.Open();local display=A.Resources.Settings(A.db.settings);display.groupWorld=false;display.groupMini=false
 return A
end

test('idle route selection never draws lines and known resource markers remain visible',function()
 local A=markerSetup();local node=A.Store.Observe(A.db,{mapID=1,x=.4,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 local route={mapID=1,points={point(.3),point(.6)}}
 A.Map.Refresh(A.db,route,nil)
 for _,pool in ipairs({A.Map.worldLines,A.Map.worldShadows,A.Map.miniLines}) do for _,line in ipairs(pool) do eq(line:IsShown(),false) end end
 assert(A.Map.byKey['w:node:'..node.key],'Idle world-map resources disappeared')
 LibStub=nil
end)

test('shared map filters intersect provenance materials type and resource focus in different zones',function()
 local A=markerSetup();local nodes={}
 for _,zone in ipairs({1,2}) do
  nodes[zone]={}
  for i,kind in ipairs({'herb','ore'}) do nodes[zone][kind]=A.Store.Observe(A.db,{mapID=zone,x=.2+i*.1,y=.5,kind=kind,materialID=kind,source='imported'}) end
 end
 WorldMapFrame.GetMapID=function() return 2 end
 A.Selection.MarkerSettings(A.db.settings).source='confirmed';A.Map.Refresh(A.db,nil);eq(next(A.Map.byKey),nil)
 A.Selection.MarkerSettings(A.db.settings).source='combined';A.Selection.MarkerSettings(A.db.settings).materials={herb=true};A.Map.Refresh(A.db,nil)
 assert(A.Map.byKey['w:node:'..nodes[2].herb.key]);assert(A.Map.byKey['m:node:'..nodes[1].herb.key]);eq(A.Map.byKey['w:node:'..nodes[2].ore.key],nil)
 A.Map.SetNodeFocus(2,{ore=true},nodes[2].ore.key);A.Map.Refresh(A.db,nil);eq(A.Map.byKey['w:node:'..nodes[2].ore.key],nil)
 A.Map.SetNodeFocus(nil);A.Selection.MarkerSettings(A.db.settings).source='none';A.Map.Refresh(A.db,nil);eq(next(A.Map.byKey),nil)
 LibStub=nil
end)

test('Gathering kind filters both map marker layers and switching retires the old type',function()
 local A=markerSetup();local nodes={}
 for _,kind in ipairs({'herb','ore'}) do nodes[kind]=A.Store.Observe(A.db,{mapID=1,x=.4,y=.5,kind=kind,materialID=kind,name=kind,source='imported'}) end
 for _,kind in ipairs({'herb','ore','both','herb'}) do
  A.Selection.MarkerSettings(A.db.settings).kind=kind;A.Map.Refresh(A.db,nil)
  for nodeKind,node in pairs(nodes) do for _,prefix in ipairs({'w:node:','m:node:'}) do
   eq(A.Map.byKey[prefix..node.key]~=nil,kind=='both' or kind==nodeKind)
  end end
 end
 assert(A.Map.SetNodeFocus(1,{ore=true},nodes.ore.key));A.Map.Refresh(A.db,nil)
 eq(A.Map.byKey['w:node:'..nodes.ore.key],nil)
 LibStub=nil
end)

test('node texture opacity is independent per map and layer without tinting difficulty colours',function()
 local A=markerSetup();local s=A.Resources.Settings(A.db.settings)
 A.Client.Position=function() return point(.35) end
 s.worldIconOpacity=.25;s.miniIconOpacity=.5;s.miniOutlineOpacity=.75;s.hideDistance=0
 local n=A.Store.Observe(A.db,{mapID=1,x=.4,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 A.Map.Refresh(A.db,nil)
 local world=A.Map.byKey['w:node:'..n.key];local mini=A.Map.byKey['m:node:'..n.key]
 eq(world.icon:GetAlpha(),.25);eq(mini.icon:GetAlpha(),.5);eq(mini.outline:GetAlpha(),.75)
 local color=A.Resources.colors.yellow;for i=1,3 do eq(mini.outline.vertexColor[i],color[i]) end
 s.hideDistance=1000;A.Map.Refresh(A.db,nil);eq(mini.icon:IsShown(),false);eq(mini.outline:GetAlpha(),.75)
 LibStub=nil
end)

test('zero-opacity nodes do not catch hover and reused navigation markers reset their opacity',function()
 local A=markerSetup();module('Editor',A);module('Follower',A);A.Client.Size=function() return 1000,500 end
 local s=A.Resources.Settings(A.db.settings);s.worldIconOpacity=0;s.miniIconOpacity=0;s.miniOutlineOpacity=0
 local n=A.Store.Observe(A.db,{mapID=1,x=.4,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 A.Map.Refresh(A.db,nil)
 local world=A.Map.byKey['w:node:'..n.key];local mini=A.Map.byKey['m:node:'..n.key]
 eq(world.mouse,false);eq(mini.mouseMotion,false)
 s.world=false;s.mini=false;A.Map.Refresh(A.db,nil)
 local route={mapID=1,points={point(.3),point(.6)}}
 local editor=A.Editor.New(route);A.Map.SetEditor(editor);A.Map.Refresh(A.db,editor.draft)
 eq(A.Map.byKey['w:point:1'].icon:GetAlpha(),1)
 A.Map.SetEditor(nil);local f=A.Follower.New(route,point(.1),distance);A.Map.Refresh(A.db,f.route,f)
 eq(A.Map.byKey['m:point:'..f.index].outline:GetAlpha(),1)
 LibStub=nil
end)

test('world route uses fine gold strokes with subtle edges and stable width while zooming',function()
 local A=markerSetup();module('Follower',A);A.Client.Size=function() return 1000,500 end
 local route={mapID=1,points={point(.3),point(.6),point(.8)}}
 local follower=A.Follower.New(route,point(.1),distance)
 for _,zoom in ipairs({1,2,4}) do
  WorldMapFrame.GetCanvasScale=function() return zoom end
  A.Map.Refresh(A.db,route,follower)
  local leg,path=A.Map.worldLines[1],A.Map.worldLines[2]
  assert(path.color[1]>.75 and path.color[2]>.5 and path.color[3]<.5,'World route is not warm gold')
  near(path.thickness*zoom,1.5);near(leg.thickness*zoom,2)
  assert(path.color[4]>=.7 and path.color[4]<=.9,'Route opacity overwhelms the map')
  assert(path.shadow.color[4]<=.4,'Route has a heavy dark outline')
  assert(path.shadow.thickness*zoom<=3,'Route outline overwhelms the map')
 end
 LibStub=nil
end)

test('world route strokes render above map artwork but below resource pins for following and editing',function()
 local A=markerSetup();module('Follower',A);module('Editor',A);A.Client.Size=function() return 1000,500 end
 local canvas=WorldMapFrame:GetCanvas();local artwork=CreateFrame('Frame',nil,canvas);artwork:SetFrameLevel(canvas:GetFrameLevel()+5)
 local wrapper=CreateFrame('Frame',nil,canvas);wrapper:SetFrameLevel(2000)
 WorldMapFrame.GetPinFrameLevelsManager=function() return {GetFrameLevelStart=function(_,kind) eq(kind,'PIN_FRAME_LEVEL_DEFAULT');return 2000 end,GetValidFrameLevel=function() return 2200 end} end
 LibStub=function() return {AddWorldMapIconMap=function(_,_,frame) frame:SetParent(wrapper) end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
 local node=A.Store.Observe(A.db,{mapID=1,x=.4,y=.5,kind='herb',name='Peacebloom',materialID='gm:herb:401',source='imported'})
 local route={name='Visible route',mapID=1,points={point(.3),point(.6),point(.8)},loop=true}
 local follower=A.Follower.New(route,point(.1),distance)
 for _,editing in ipairs({false,true}) do
  local r=route;if editing then A.Map.SetEditor(A.Editor.New(route));r=A.Map.editor.draft end
  A.Map.Refresh(A.db,r,not editing and follower or nil)
  local stroke=A.Map.worldLines[1];assert(stroke:IsShown())
  assert(stroke:GetParent():GetFrameLevel()>artwork:GetFrameLevel(),'World route is under the map artwork')
  assert(stroke:GetParent():GetFrameLevel()<A.Map.byKey['w:node:'..node.key]:GetFrameLevel(),'Route covers resource icons')
 end
 LibStub=nil
end)

test('world route contrast and its outline stay aligned while editing and clear during map focus',function()
 local A=markerSetup();module('Editor',A);A.Client.Size=function() return 1000,500 end
 local e=A.Editor.New({mapID=1,name='Contrast',points={point(.25,.4),point(.6,.5)},loop=true});A.Map.SetEditor(e);A.editIndex=1
 A.Map.Refresh(A.db,e.draft);local stroke=A.Map.worldLines[1]
 assert(stroke.color[4]>=.7,'World route is too transparent');assert(stroke.shadow and stroke.shadow:IsShown(),'No contrast edge against map terrain')
 local x,y=.25,.4;WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition=function() return x,y end
 local handle=A.Map.byKey['w:point:1'];handle.scripts.OnDragStart(handle);x,y=.35,.5;handle.scripts.OnUpdate(handle,.016)
 for _,line in ipairs(A.Map.dragLinks) do near(line.lineStart[3],line.shadow.lineStart[3]);near(line.lineEnd[4],line.shadow.lineEnd[4]) end
 handle.scripts.OnDragStop(handle);A.Map.SetEditor(nil)
 assert(A.Map.SetNodeFocus(1,{['gm:herb:401']=true}));A.Map.Refresh(A.db,e.draft)
 for _,line in ipairs(A.Map.worldLines) do eq(line:IsShown(),false);if line.shadow then eq(line.shadow:IsShown(),false) end end
 LibStub=nil
end)

test('world route stays above exploration and highlight pins while below native resource pins',function()
 local A=markerSetup();module('Follower',A);module('Editor',A);A.Client.Size=function() return 1000,500 end
 -- Blizzard's explored terrain is itself a pin above DEFAULT, not a detail-layer child.
 local levels={PIN_FRAME_LEVEL_DEFAULT=2000,PIN_FRAME_LEVEL_MAP_EXPLORATION=2001,PIN_FRAME_LEVEL_MAP_HIGHLIGHT=2007,PIN_FRAME_LEVEL_AREA_POI=2020}
 local manager={minLevel=2000,GetFrameLevelStart=function(_,kind) return levels[kind] or 2000 end,GetFrameLevelRange=function() return 1 end}
 WorldMapFrame.GetPinFrameLevelsManager=function() return manager end
 local route={mapID=1,name='Explored terrain',points={point(.3),point(.6)},loop=true}
 local follower=A.Follower.New(route,point(.1),distance)
 for _,editing in ipairs({false,true}) do
  local r=route;if editing then A.Map.SetEditor(A.Editor.New(route));r=A.Map.editor.draft end
  A.Map.Refresh(A.db,r,not editing and follower or nil)
  for _,pool in ipairs({A.Map.worldLines,A.Map.worldShadows}) do
   local stroke=pool[1];assert(stroke:IsShown())
   assert(stroke:GetParent():GetFrameLevel()>levels.PIN_FRAME_LEVEL_MAP_HIGHLIGHT,'Exploration or highlight pin covers route')
   assert(stroke:GetParent():GetFrameLevel()<levels.PIN_FRAME_LEVEL_AREA_POI,'Route covers native resource pin tier')
  end
 end
 LibStub=nil
end)

test('world route follows OpenMap terrain priority without raising lines on other maps',function()
 local A=markerSetup();module('Editor',A);A.Client.Size=function() return 1000,500 end
 local route={mapID=1,points={point(.3),point(.6)}}
 A.Map.SetEditor({draft=route})
 local stitched=true;local artTop=2300
 OpenMapAPI={major=1,IsStitched=function() return stitched end,ArtTopLevel=function() return artTop end}
 WorldMapFrame.GetPinFrameLevelsManager=function() return {minLevel=2000,GetFrameLevelStart=function(_,kind) return kind=='PIN_FRAME_LEVEL_MAP_HIGHLIGHT' and 2200 or 2000 end,GetFrameLevelRange=function() return 1 end} end
 A.Map.Refresh(A.db,route);local layer=A.Map.worldLines[1]:GetParent()
 assert(layer:GetFrameLevel()>artTop,'OpenMap terrain covers route')
 artTop=2400;A.Map.Refresh(A.db,route);assert(layer:GetFrameLevel()>artTop,'Route priority did not follow rebuilt map art')
 stitched=false;A.Map.Refresh(A.db,route);assert(layer:GetFrameLevel()<2300,'Inactive stitched map still controls route priority')
 OpenMapAPI=nil;LibStub=nil
end)

test('world route fallback keeps editor above it without visible nodes',function()
 local A=markerSetup();module('Editor',A);A.Resources.Settings(A.db.settings).world=false
 WorldMapFrame.GetPinFrameLevelsManager=function() return {minLevel=1700,GetFrameLevelStart=function() return 2000 end} end
 local e=A.Editor.New({mapID=1,name='Priority',points={point(.3),point(.6)}});A.Map.SetEditor(e);A.Map.Refresh(A.db,e.draft)
 local layer=A.Map.worldLines[1]:GetParent();assert(layer:GetFrameLevel()>2000,'Fallback route is below the default native tier')
 assert(A.Map.editLayer:GetFrameLevel()>layer:GetFrameLevel(),'Route layer covers editor handles with world markers hidden')
 LibStub=nil
end)

test('world route respects complete terrain tier ranges and safely handles unavailable optional APIs',function()
 local A=markerSetup();module('Editor',A);A.Client.Size=function() return 1000,500 end
 local route={mapID=1,points={point(.3),point(.6)}}
 A.Map.SetEditor({draft=route})
 local manager={GetFrameLevelStart=function(_,kind) return kind=='PIN_FRAME_LEVEL_MAP_HIGHLIGHT' and 2200 or 2000 end,GetFrameLevelRange=function() return 8 end}
 WorldMapFrame.GetPinFrameLevelsManager=function() return manager end
 OpenMapAPI={major=1,IsStitched=function() error('not ready') end,ArtTopLevel=function() error('not ready') end}
 A.Map.Refresh(A.db,route);local layer=A.Map.worldLines[1]:GetParent();eq(layer:GetFrameLevel(),2208)
 OpenMapAPI.IsStitched=function() return true end;A.Map.Refresh(A.db,route);eq(layer:GetFrameLevel(),2208)
 OpenMapAPI.ArtTopLevel=function() return 0/0 end;A.Map.Refresh(A.db,route);eq(layer:GetFrameLevel(),2208)
 OpenMapAPI=nil;WorldMapFrame.GetPinFrameLevelsManager=function() error('not ready') end
 A.Map.Refresh(A.db,route);eq(layer:GetFrameLevel(),WorldMapFrame:GetCanvas():GetFrameLevel()+10)
 LibStub=nil
end)

test('editor drag follows the pointer and adjacent route lines between slow map ticks',function()
 local A=markerSetup();module('Editor',A);A.Client.Size=function() return 1000,500 end
 local cursorX,cursorY=.21,.51;WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition=function() return cursorX,cursorY end
 local original={mapID=1,name='Drag',points={point(.2,.5),point(.6,.5),point(.8,.7)},loop=true}
 local editor=A.Editor.New(original);A.Map.SetEditor(editor);A.editIndex=1;A.Map.Refresh(A.db,editor.draft)
 local handle=A.Map.byKey['w:point:1'];assert(handle);handle.scripts.OnDragStart(handle)
 assert(handle.scripts.OnUpdate,'Dragging waits for the half-second full map refresh')
 local calls=0;local refresh=A.Map.Refresh;A.Map.Refresh=function(...) calls=calls+1;return refresh(...) end
 cursorX,cursorY=.31,.56;handle.scripts.OnUpdate(handle,.016)
 near(editor.draft.points[1].x,.3);near(editor.draft.points[1].y,.55)
 near(original.points[1].x,.2);eq(calls,0)
 local moved=false;for _,line in ipairs(A.Map.worldLines) do if line:IsShown() and line.lineStart then
  if math.abs(line.lineStart[3]-.3*WorldMapFrame.canvas:GetWidth())<.00001 then moved=true end
 end end;assert(moved,'Connected route lines lag behind the dragged point')
 handle.scripts.OnDragStop(handle);eq(handle.scripts.OnUpdate,nil);eq(A.Map.dragIndex,nil)
 LibStub=nil
end)

test('editor handles remain above the map click layer and expose their selected waypoint number',function()
 local A=markerSetup();module('Editor',A)
 local editor=A.Editor.New({mapID=1,name='Handles',points={point(.3),point(.6)}});A.Map.SetEditor(editor);A.editIndex=2
 A.Map.Refresh(A.db,editor.draft);local handle=A.Map.byKey['w:point:2']
 assert(handle:GetFrameLevel()>A.Map.editLayer:GetFrameLevel(),'Map click layer covers draggable handles')
 assert(handle.number and handle.number:GetText()=='2','Selected waypoint has no clear numbered handle')
 LibStub=nil
end)

test('editor handles and help stay above raised native map pin wrappers',function()
 local A=markerSetup();module('Editor',A);module('Skin',A)
 local wrapper=CreateFrame('Frame',nil,WorldMapFrame:GetCanvas());wrapper:SetFrameLevel(2400)
 LibStub=function() return {AddWorldMapIconMap=function(_,_,frame) frame:SetParent(wrapper) end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
 WorldMapFrame.GetPinFrameLevelsManager=function() return {GetValidFrameLevel=function(_,kind) eq(kind,'PIN_FRAME_LEVEL_TOPMOST');return 2600 end} end
 local node=A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 local e=A.Editor.New({mapID=1,name='Overlap',points={point(.3),point(.6)}});A.Map.SetEditor(e);A.editIndex=1
 A.Map.Refresh(A.db,e.draft);local handle=A.Map.byKey['w:point:1'];local icon=A.Map.byKey['w:node:'..node.key]
 assert(handle:GetFrameLevel()>icon:GetFrameLevel(),'Resource icon covers editing handle')
 assert(A.Map.editLayer:GetFrameLevel()>2600,'Native topmost pin covers editing click layer')
 assert(A.Map.editorHelp:GetFrameLevel()>handle:GetFrameLevel(),'Native map pins cover editor help/actions')
 LibStub=nil
end)

test('editor dragging clamps bounds and stops safely when map or point changes',function()
 local A=markerSetup();module('Editor',A);local x,y=.21,.51
 WorldMapFrame.ScrollContainer.GetNormalizedCursorPosition=function() return x,y end
 local e=A.Editor.New({mapID=1,name='Safe drag',points={point(.2),point(.6)}});A.Map.SetEditor(e);A.editIndex=1;A.Map.Refresh(A.db,e.draft)
 local f=A.Map.byKey['w:point:1'];f.scripts.OnDragStart(f);x,y=1.5,-.3;f.scripts.OnUpdate(f,.016)
 near(e.draft.points[1].x,1);near(e.draft.points[1].y,0)
 WorldMapFrame:Hide();eq(A.Map.dragIndex,nil);eq(f.scripts.OnUpdate,nil)
 WorldMapFrame:Show();x,y=1,0;A.Map.Refresh(A.db,e.draft);f=A.Map.byKey['w:point:1'];f.scripts.OnDragStart(f)
 WorldMapFrame.GetMapID=function() return 2 end;f.scripts.OnUpdate(f,.016);eq(A.Map.dragIndex,nil)
 WorldMapFrame.GetMapID=function() return 1 end;A.Map.Refresh(A.db,e.draft);f=A.Map.byKey['w:point:1'];f.scripts.OnDragStart(f)
 e:Delete(1);f.scripts.OnUpdate(f,.016);eq(A.Map.dragIndex,nil);near(e.draft.points[1].x,.6)
 LibStub=nil
end)

test('editor handle sizes compensate zoom without changing map coordinates or adding a drag release point',function()
 local A=markerSetup();module('Editor',A);local zoom=1
 WorldMapFrame.GetCanvasScale=function() return zoom end
 local e=A.Editor.New({mapID=1,name='Zoom',points={point(.25,.4),point(.6)}});A.Map.SetEditor(e);A.editIndex=1
 A.Map.Refresh(A.db,e.draft);local f=A.Map.byKey['w:point:1'];local size=f.icon:GetWidth()
 zoom=2;A.Map.Refresh(A.db,e.draft);near(f.icon:GetWidth()*zoom,size)
 local count=#e.draft.points;f.scripts.OnDragStart(f);f.scripts.OnDragStop(f)
 A.Map.editLayer.scripts.OnMouseUp(A.Map.editLayer,'LeftButton');eq(#e.draft.points,count)
 A.Map.editLayer.scripts.OnMouseDown(A.Map.editLayer,'LeftButton');A.Map.editLayer.scripts.OnMouseUp(A.Map.editLayer,'LeftButton');eq(#e.draft.points,count+1)
 A.Map.SetEditor(nil);eq(f:IsShown(),false);eq(f.scripts.OnUpdate,nil);LibStub=nil
end)
test('node markers ignore route filters hide nearby icons and retain hollow outlines',function()
 local A=markerSetup(); local n=A.Store.Observe(A.db,{mapID=1,x=.11,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 A.Map.Refresh(A.db,nil)
 local mini=A.Map.byKey['m:node:'..n.key];local world=A.Map.byKey['w:node:'..n.key]
 assert(mini and world,'Route filters must not suppress known nodes')
 eq(mini.icon:IsShown(),false);eq(mini.outline:IsShown(),true);eq(mini:GetWidth(),24);eq(mini.mouse,false)
 eq(world.icon:IsShown(),true);near(mini.outline.vertexColor[1],1)
 local s=A.Resources.Settings(A.db.settings);s.outline='square';s.icon=false;A.Map.Refresh(A.db,nil)
 assert(mini.outline.texture:find('NodeSquare'));eq(world.icon:IsShown(),true);eq(world.outline:IsShown(),false)
 s.mini=false;A.Map.Refresh(A.db,nil);eq(mini:IsShown(),false);eq(A.Map.byKey['m:node:'..n.key],nil)
 assert(A.Map.byKey['w:node:'..n.key]);s.world=false;A.Map.Refresh(A.db,nil);eq(world:IsShown(),false)
 LibStub=nil
end)
test('minimap node cap preserves nearest locations even when imported last',function()
 local A=markerSetup()
 for i=1,400 do A.Store.Observe(A.db,{mapID=1,x=.5+i/10000,y=.5,kind='herb',materialID='far'..i,name='Far',source='imported'}) end
 local nearNode=A.Store.Observe(A.db,{mapID=1,x=.105,y=.5,kind='herb',materialID='near',name='Near',source='imported'})
 A.Map.Refresh(A.db,nil);assert(A.Map.byKey['m:node:'..nearNode.key]);eq(A.Map.limited,true);LibStub=nil
end)

test('marker resizing reuses registrations and moving a world node retires its previous wrapper',function()
 local A=markerSetup();local world,mini,removed=0,0,0
 LibStub=function() return {AddWorldMapIconMap=function() world=world+1 end,AddMinimapIconMap=function() mini=mini+1 end,RemoveWorldMapIcon=function() removed=removed+1 end,RemoveMinimapIcon=function() end} end
 local n=A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 A.Map.Refresh(A.db,nil);eq(world,1);eq(mini,1)
 local s=A.Resources.Settings(A.db.settings)
 for _,size in ipairs({28,32,36,40,24}) do s.outlineSize=size;A.Map.Refresh(A.db,nil) end
 eq(world,1);eq(mini,1);eq(removed,0)
 n.x=.31;A.Map.Refresh(A.db,nil);eq(world,2);eq(removed,1);LibStub=nil
end)

local function segmentDistance(x,y,l)
 local ax,ay=l.lineStart[3],l.lineStart[4];local bx,by=l.lineEnd[3],l.lineEnd[4]
 local dx,dy=bx-ax,by-ay;local len=dx*dx+dy*dy
 local t=len>0 and math.max(0,math.min(1,((x-ax)*dx+(y-ay)*dy)/len)) or 0
 return math.sqrt((x-ax-t*dx)^2+(y-ay-t*dy)^2)
end
test('filtered-out node markers still leave room for native minimap tracking dots',function()
 local A=markerSetup();module('Follower',A);A.Client.Position=function() return point(.5) end;A.Client.Size=function() return 1000,500 end
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end;A.db.settings.kind='herb'
 local ore=A.Store.Observe(A.db,{mapID=1,x=.6,y=.5,kind='ore',materialID='gm:ore:201',name='Copper',source='imported'})
 local route={mapID=1,points={point(.35),point(.65)}};local f=A.Follower.New(route,point(.5),distance)
 A.Map.Refresh(A.db,f.route,f);eq(A.Map.byKey['m:node:'..ore.key],nil)
 local shown=0;for _,line in ipairs(A.Map.miniLines) do if line:IsShown() then
  shown=shown+1;assert(segmentDistance(50,0,line)>=7,'Kind filtering removed native tracking clearance')
 end end;assert(shown>0)
 C_Minimap=nil;GetCVar=nil;LibStub=nil
end)

test('minimap route leaves tracking clearance even with addon node markers disabled',function()
 local A=markerSetup();A.Client.Position=function() return point(.5) end;A.Client.Size=function() return 1000,500 end
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end
 A.Resources.Settings(A.db.settings).mini=false
 A.Store.Observe(A.db,{mapID=1,x=.6,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 local route={mapID=1,points={point(.35),point(.65)}}
 local follower={Snapshot=function() return {status='running',index=2,target=route.points[2],visited={}} end}
 A.Map.Refresh(A.db,route,follower)
 local visible=0
 for _,l in ipairs(A.Map.miniLines) do if l:IsShown() then
  visible=visible+1;assert(segmentDistance(50,0,l)>=7,'Route stroke covers known tracking-dot centre')
  assert(l.thickness<=1.5 and l.color[4]<=.6,'Minimap route remains too thick or opaque')
 end end
 assert(visible>0,'Route still needs to be visible')
 local target=A.Map.byKey['m:point:2'];assert(target);eq(target.icon:IsShown(),false);eq(target.outline:IsShown(),true)
 eq(A.Map.worldLines[1].thickness,2);eq(A.Map.worldLines[1].color[4],.95)
 C_Minimap=nil;GetCVar=nil;LibStub=nil
end)
test('minimap route visibility toggle retires its lines without changing world guidance',function()
 local A=markerSetup();A.Client.Position=function() return point(.5) end;A.Client.Size=function() return 1000,500 end
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end
 local route={mapID=1,points={point(.35),point(.65)}}
 module('Follower',A);local follower=A.Follower.New(route,point(.5),distance)
 A.Map.Refresh(A.db,route,follower);assert(A.Map.miniLines[1]:IsShown())
 A.Resources.Settings(A.db.settings).routeLines=false;A.Map.Refresh(A.db,route,follower)
 for _,l in ipairs(A.Map.miniLines) do eq(l:IsShown(),false) end
 assert(A.Map.worldLines[1]:IsShown());C_Minimap=nil;GetCVar=nil;LibStub=nil
end)

test('minimap clear areas merge overlaps and handle reversed degenerate and covered segments',function()
 local A={};module('Store',A);module('Client',A);module('Map',A);local gap=A.Map.GapSegments
 local pieces=gap(0,0,20,0,{{x=10,y=0,r=3}},1);eq(#pieces,2);near(pieces[1][3],6);near(pieces[2][1],14)
 pieces=gap(0,0,20,0,{{x=12,y=0,r=3},{x=7,y=0,r=3}},0);eq(#pieces,2);near(pieces[1][3],4);near(pieces[2][1],15)
 pieces=gap(20,0,0,0,{{x=10,y=0,r=3}},1);eq(#pieces,2);near(pieces[1][3],14);near(pieces[2][1],6)
 eq(#gap(0,0,0,0,{},0),0);eq(#gap(0,0,20,0,{{x=10,y=0,r=30}},0),0)
 pieces=gap(0,0,20,0,{{x=100,y=0,r=3},{x=10,y=3,r=3}},0);eq(#pieces,1);near(pieces[1][1],0);near(pieces[1][3],20)
end)
test('tracking clearance follows rotating non-square minimaps and zoom changes',function()
 local A=markerSetup();A.Client.Position=function() return point(.5) end;A.Client.Size=function() return 1000,500 end
 A.Client.Facing=function() return math.pi/2 end;GetCVar=function() return '1' end
 A.Resources.Settings(A.db.settings).mini=false;Minimap:SetSize(200,140)
 A.Store.Observe(A.db,{mapID=1,x=.55,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='confirmed'})
 local route={mapID=1,points={point(.45),point(.57)}}
 module('Follower',A);local follower=A.Follower.New(route,point(.5),distance)
 for _,radius in ipairs({100,200}) do
  C_Minimap={GetViewRadius=function() return radius end};A.Map.Refresh(A.db,route,follower)
  local visible=0
  for _,l in ipairs(A.Map.miniLines) do if l:IsShown() then
   visible=visible+1;assert(segmentDistance(0,-50/radius*70,l)>=7-.00001,'Rotated tracking dot was covered')
  end end
  assert(visible>0)
 end
 C_Minimap=nil;GetCVar=nil;LibStub=nil
end)


test('world and minimap routes follow navigation state with world editing only',function()
 local A=markerSetup();module('Follower',A);A.Client.Position=function() return point(.5) end;A.Client.Size=function() return 1000,500 end
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end
 local route={mapID=1,points={point(.35),point(.65)}}
 local follower=A.Follower.New(route,point(.5),distance)
 for _,status in ipairs({'running','paused','suspended','complete','stopped','selected','editing'}) do
  follower.status=status
  local active=status=='running' or status=='paused' or status=='suspended'
  local current=(status~='selected' and status~='editing') and follower or nil
  A.Map.editor=status=='editing' and {draft=route} or nil
  A.Map.Refresh(A.db,route,current)
  local visible=0;for _,l in ipairs(A.Map.miniLines) do if l:IsShown() then visible=visible+1 end end
  eq(visible>0,active);eq(A.Map.targetIndex,active and follower.index or nil)
  if not active then eq(A.Map.byKey['m:point:'..follower.index],nil) end
  for _,pool in ipairs({A.Map.worldLines,A.Map.worldShadows}) do
   eq(pool[1]:IsShown(),active or status=='editing')
  end
 end
 A.Map.Refresh(A.db,nil,nil);eq(A.Map.targetIndex,nil)
 C_Minimap=nil;GetCVar=nil;LibStub=nil
end)


test('world icons stay above the HBD wrapper after opening and refreshing a raised map',function()
 local A=markerSetup();local wrapper=CreateFrame('Frame',nil,WorldMapFrame:GetCanvas());local additions=0
 LibStub=function() return {AddWorldMapIconMap=function(_,_,icon)
  additions=additions+1;icon:SetParent(wrapper);icon:SetFrameLevel(wrapper:GetFrameLevel()+1);icon:Show()
 end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
 local node=A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 wrapper:SetFrameLevel(700);A.Map.Refresh(A.db,nil)
 local icon=A.Map.byKey['w:node:'..node.key]
 for _,level in ipairs({700,900,1200}) do
  wrapper:SetFrameLevel(level);A.Map.Refresh(A.db,nil)
  assert(icon:GetFrameLevel()>wrapper:GetFrameLevel(),'World node was lowered below its map wrapper')
  eq(icon.icon:IsShown(),true);eq(icon.outline:IsShown(),false)
 end
 eq(additions,1);LibStub=nil
end)

test('minimap node hover reports resource details without capturing clicks and hides on retirement',function()
 local A=markerSetup();local node=A.Store.Observe(A.db,{mapID=1,x=.13,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='confirmed',time=100})
 local owner,lines
 GameTooltip.SetOwner=function(_,value) owner=value end
 GameTooltip.IsOwned=function(_,value) return owner==value end
 GameTooltip.SetText=function(_,value) lines={value} end
 GameTooltip.AddLine=function(_,value) lines[#lines+1]=value end
 GameTooltip.AddDoubleLine=function(_,left,right) lines[#lines+1]=left;lines[#lines+1]=right end
 GameTooltip:Hide();A.Map.Refresh(A.db,nil)
 local pin=A.Map.byKey['m:node:'..node.key]
 eq(pin.mouse,false);eq(pin.mouseClicks,false);eq(pin.mouseMotion,true)
 pin.scripts.OnEnter(pin);eq(owner,pin);eq(GameTooltip:IsShown(),true)
 local details=table.concat(lines,'\n');assert(details:find('Peacebloom',1,true));assert(details:find('Personally gathered',1,true))
 assert(details:find('Herbalism',1,true));assert(details:find('13.0, 50.0',1,true));assert(details:find('Reference data',1,true))
 pin.scripts.OnLeave(pin);eq(GameTooltip:IsShown(),false)
 pin.scripts.OnEnter(pin);A.Resources.Settings(A.db.settings).mini=false;A.Map.Refresh(A.db,nil)
 eq(pin:IsShown(),false);eq(GameTooltip:IsShown(),false);LibStub=nil
end)


test('world waypoint handles appear only in the route editor and retire when editing ends',function()
 local A=markerSetup();module('Follower',A);module('Editor',A);A.Client.Size=function() return 1000,500 end
 local node=A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='confirmed'})
 local route={name='World preview',mapID=1,loop=true,points={point(.3),point(.4),point(.5)}}
 local function noWorldHandles(visible)
  for key in pairs(A.Map.byKey) do assert(not key:find('w:point:',1,true),'Non-editing map shows a numbered waypoint handle') end
  assert(A.Map.byKey['w:node:'..node.key]);for _,line in ipairs(A.Map.worldLines) do eq(line:IsShown(),visible) end
 end
 A.Map.Refresh(A.db,route,nil);noWorldHandles(false)
 local follower=A.Follower.New(route,point(.1),distance)
 A.Map.Refresh(A.db,follower.route,follower);noWorldHandles(true)
 assert(A.Map.byKey['m:point:'..follower.index],'Minimap destination must remain while following')
 local editor=A.Editor.New(route);A.Map.SetEditor(editor);A.editIndex=2
 A.Map.Refresh(A.db,editor.draft,nil)
 local handle=A.Map.byKey['w:point:2'];assert(handle);eq(handle.mouse,true)
 handle.scripts.OnClick(handle);eq(A.editIndex,2)
 A.Map.SetEditor(nil)
 for _,pool in ipairs({A.Map.worldLines,A.Map.worldShadows}) do for _,line in ipairs(pool) do eq(line:IsShown(),false) end end
 A.Map.Refresh(A.db,route,nil);noWorldHandles(false);eq(handle:IsShown(),false)
 for i=1,3 do A.Map.Refresh(A.db,follower.route,follower);noWorldHandles(true) end
 LibStub=nil
end)


test('node tooltips show two-column skill guidance and refresh rank on each hover',function()
 local A=markerSetup();local skill=109;A.Resources.Skills=function() return {herb=skill} end
 local node=A.Store.Observe(A.db,{mapID=1,x=.13,y=.5,kind='herb',materialID='gm:herb:403',name='Earthroot',source='imported'})
 local lines,doubles
 GameTooltip.SetText=function(_,value) lines={value};doubles={} end
 GameTooltip.AddLine=function(_,value) lines[#lines+1]=value end
 GameTooltip.AddDoubleLine=function(_,left,right,lr,lg,lb,rr,rg,rb) lines[#lines+1]=left;lines[#lines+1]=right;doubles[#doubles+1]={left=left,right=right,color={rr,rg,rb}} end
 A.Map.Refresh(A.db,nil)
 for _,prefix in ipairs({'m:node:','w:node:'}) do
  local pin=A.Map.byKey[prefix..node.key];pin.scripts.OnEnter(pin)
  local text=table.concat(lines,'\n');assert(text:find('Requires 15 (you have 109)',1,true))
  assert(text:find('Sometimes a skill-up',1,true));assert(text:find('Turns grey at +6 skill',1,true))
  assert(text:find('From GatherMate2',1,true));assert(text:find('Reference data',1,true))
  local row;for _,value in ipairs(doubles) do if value.right=='Sometimes a skill-up' then row=value end end
  assert(row);near(row.color[1],A.Resources.colors.green[1]);near(row.color[2],A.Resources.colors.green[2])
 end
 skill=110;A.Map.byKey['m:node:'..node.key].scripts.OnEnter(A.Map.byKey['m:node:'..node.key])
 assert(table.concat(lines,'\n'):find('Turns grey at +5 skill',1,true));LibStub=nil
end)


test('minimap colours and tooltip guidance receive the same cap and bonus context',function()
 local A=markerSetup();local rank,cap,bonus=75,75,0
 A.Resources.Skills=function() return {herb=rank},{herb={maxRank=cap,bonus=bonus}} end
 local earth=A.Store.Observe(A.db,{mapID=1,x=.13,y=.5,kind='herb',materialID='gm:herb:403',name='Earthroot',source='imported'})
 local steel=A.Store.Observe(A.db,{mapID=1,x=.14,y=.5,kind='herb',materialID='gm:herb:409',name='Wild Steelbloom',source='imported'})
 local right;GameTooltip.AddDoubleLine=function(_,left,value) if left:find('Requires',1,true) then right=value end end
 A.Map.Refresh(A.db,nil);local pin=A.Map.byKey['m:node:'..earth.key]
 near(pin.outline.vertexColor[1],A.Resources.colors.grey[1]);pin.scripts.OnEnter(pin);eq(right,'At profession skill cap')
 rank,cap,bonus=110,150,5;A.Map.Refresh(A.db,nil);pin=A.Map.byKey['m:node:'..steel.key]
 near(pin.outline.vertexColor[1],A.Resources.colors.orange[1]);pin.scripts.OnEnter(pin);eq(right,'High skill-up chance')
 LibStub=nil
end)


test('atlas map focus filters only world icons preserves minimap guidance and clears on map close',function()
 local A=markerSetup();module('Follower',A);A.Client.Position=function() return point(.5) end;A.Client.Size=function() return 1000,500 end
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end
 local earth=A.Store.Observe(A.db,{mapID=1,x=.55,y=.5,kind='herb',materialID='gm:herb:403',name='Earthroot',source='imported'})
 local silver=A.Store.Observe(A.db,{mapID=1,x=.6,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
 local route={mapID=1,points={point(.35),point(.65)}};local follower=A.Follower.New(route,point(.5),distance)
 A.Map.Refresh(A.db,route,follower);assert(A.Map.SetNodeFocus)
 assert(A.Map.SetNodeFocus(1,{['gm:herb:403']=true},earth.key,'combined'));A.Map.Refresh(A.db,route,follower)
 assert(A.Map.byKey['w:node:'..earth.key]);eq(A.Map.byKey['w:node:'..silver.key],nil)
 assert(A.Map.byKey['m:node:'..silver.key]);eq(A.Map.byKey['w:node:'..earth.key].icon:GetWidth(),20)
 eq(A.Map.byKey['w:node:'..earth.key].outline:IsShown(),false)
 for _,line in ipairs(A.Map.worldLines) do eq(line:IsShown(),false) end
 local shown=0;for _,line in ipairs(A.Map.miniLines) do if line:IsShown() then shown=shown+1 end end;assert(shown>0)
 WorldMapFrame:Hide();eq(A.Map.nodeFocus,nil);WorldMapFrame:Show();A.Map.Refresh(A.db,route,follower)
 assert(A.Map.byKey['w:node:'..silver.key]);eq(A.Map.byKey['w:node:'..earth.key].icon:GetWidth(),14)
 assert(A.Map.worldLines[1]:IsShown());eq(A.db.settings.source,'combined')
 C_Minimap=nil;GetCVar=nil;LibStub=nil
end)

test('explicit resource focus temporarily works with world markers disabled without changing preferences',function()
 local A=markerSetup();A.Resources.Settings(A.db.settings).world=false
 local node=A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:403',name='Earthroot',source='confirmed'})
 assert(A.Map.SetNodeFocus);assert(A.Map.SetNodeFocus(1,{['gm:herb:403']=true},node.key,'confirmed'))
 A.Map.Refresh(A.db,nil);assert(A.Map.byKey['w:node:'..node.key]);eq(A.db.settings.nodeDisplay.world,false)
 WorldMapFrame:Hide();A.Map.Refresh(A.db,nil);eq(A.Map.byKey['w:node:'..node.key],nil)
 assert(A.Map.byKey['m:node:'..node.key]);eq(A.Map.SetNodeFocus(1,{}),nil);eq(A.Map.nodeFocus,nil);LibStub=nil
end)

test('focused selected location is visible even beyond the world icon cap',function()
 local A=markerSetup()
 for i=1,410 do
  A.db.nodes[1]=A.db.nodes[1] or {}
  A.db.nodes[1][i]={mapID=1,x=i/1000,y=.5,kind='herb',materialID='gm:herb:403',name='Earthroot',key='dense'..i,imported=true}
 end
 assert(A.Map.SetNodeFocus(1,{['gm:herb:403']=true},'dense410'))
 A.Map.Refresh(A.db,nil);assert(A.Map.byKey['w:node:dense410'],'Selected location omitted by world icon cap')
 local count=0;for key in pairs(A.Map.byKey) do if key:find('w:node:',1,true) then count=count+1 end end
 eq(count,400);eq(A.db.nodes[1][1].key,'dense1');LibStub=nil
end)
