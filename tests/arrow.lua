local function arrowSetup()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,m in ipairs({'Store','Client','Skin','Arrow'}) do module(m,A) end
 A.db=A.Store.Open();A.Client.Size=function() return 1000,500 end
 return A
end
local function delta(a,b) return (b-a+math.pi)%(2*math.pi)-math.pi end

for _,arrowFirst in ipairs({false,true}) do
 test('arrow stays above gameplay and below open panels when built '..(arrowFirst and 'before' or 'after')..' the main panel',function()
  local A=arrowSetup();moduleUI(A);A.Client.Position=function() return point(.2) end
  if arrowFirst then A.Arrow.Build() end
  assert(A.UI.Build());A.UI.OpenRoutes()
  A.db.settings.arrowNodeName=true
  local target=point(.4);target.name='Silverleaf'
  A.Arrow.Update(point(.2),0,target,distance,{status='running',index=1,total=2})
  local arrow=A.Arrow.frame
  -- Even ordinary native panels may use MEDIUM; dialogs sit higher still.
  WorldMapFrame:SetFrameStrata('MEDIUM')
  local dialog=CreateFrame('Frame',nil,UIParent);dialog:SetFrameStrata('DIALOG')
  local strata={BACKGROUND=1,LOW=2,MEDIUM=3,HIGH=4,DIALOG=5,FULLSCREEN=6,FULLSCREEN_DIALOG=7,TOOLTIP=8}
  assert(arrow:IsShown() and A.UI.frame:IsShown())
  assert(arrow.nodeName:IsShown() and arrow.progress:IsShown())
  for _,region in ipairs({arrow,arrow.icon,arrow.shadow,arrow.label,arrow.nodeName,arrow.progress,arrow.stateGlyph,arrow.zoomHint}) do
   local layer=strata[region:GetFrameStrata()]
   assert(layer>strata.BACKGROUND,'Guide must remain visible above the gameplay background')
   for _,panel in ipairs({A.UI.frame,WorldMapFrame,dialog}) do
    assert(layer<strata[panel:GetFrameStrata()],'Guide must render below '..(panel.name or 'native dialog')..' regardless of frame creation order')
   end
  end
 end)
end

test('arrow interpolates the shortest angular path at consistent speed across frame rates',function()
 local A=arrowSetup();local smooth=A.Arrow.SmoothAngle;assert(type(smooth)=='function')
 local current=math.rad(179);local target=math.rad(-179)
 local nextAngle=smooth(current,target,1/60);assert(delta(current,nextAngle)>0 and delta(current,nextAngle)<math.rad(2))
 assert(delta(target,smooth(target,current,1/60))<0)
 local results={}
 for _,fps in ipairs({30,60,144}) do
  local angle=0;for i=1,fps/2 do angle=smooth(angle,1.5,1/fps) end
  results[#results+1]=angle;assert(angle>1.49 and angle<=1.5)
 end
 near(results[1],results[2]);near(results[2],results[3])
 eq(smooth(.4,1,0),.4);eq(smooth(.4,1,0/0),.4)
end)

test('visible arrow reads fresh facing between route ticks and blends pointer and shadow together',function()
 local A=arrowSetup();local facing=0;local reads=0;local sizes=0
 A.Client.Facing=function() reads=reads+1;return facing end
 A.Client.Size=function() sizes=sizes+1;return 1000,500 end
 local player=point(.2);local target=point(.4)
 A.Arrow.Update(player,0,target,distance,{status='running',index=1,total=2})
 local f=A.Arrow.frame;local initial=f.icon.rotation;local before=sizes
 assert(type(f.scripts.OnUpdate)=='function','Arrow requires a visible-frame update')
 facing=.9;f.scripts.OnUpdate(f,1/60)
 local step=delta(initial,f.icon.rotation);assert(step<0 and step>-.9,'Heading should start moving without snapping')
 eq(f.shadow.rotation,f.icon.rotation);eq(reads,1);eq(sizes,before)
 local second=f.icon.rotation;f.scripts.OnUpdate(f,1/60);assert(delta(second,f.icon.rotation)<0)
 for i=1,30 do f.scripts.OnUpdate(f,1/60) end
 assert(math.abs(delta(f.icon.rotation,initial-.9))<.001);eq(sizes,before)
end)

test('arrow smoothing resets on pause lost direction and hiding so resuming has no stale turn',function()
 local A=arrowSetup();A.Client.Facing=function() return 1 end
 local player=point(.2);local target=point(.4);local run={status='running',index=1,total=2}
 A.Arrow.Update(player,0,target,distance,run);local f=A.Arrow.frame;assert(f.scripts.OnUpdate)
 f.scripts.OnUpdate(f,1/60);local prior=f.icon.rotation
 A.Arrow.Update(player,0,target,distance,{status='paused',index=1,total=2})
 f.scripts.OnUpdate(f,1/60);eq(f.icon.rotation,prior);eq(f.icon:IsShown(),false)
 A.Arrow.Update(player,1,target,distance,run);near(delta(f.icon.rotation,A.Arrow.Angle(target,player,1000,500,1)),0)
 A.Arrow.Update(nil,nil,target,distance,run);eq(f.icon:IsShown(),false)
 A.Arrow.Update(player,-1,target,distance,run);near(delta(f.icon.rotation,A.Arrow.Angle(target,player,1000,500,-1)),0)
 A.Arrow.Update(nil,nil,nil,distance,nil);eq(f:IsShown(),false)
 A.Arrow.Update(player,0,target,distance,run);near(delta(f.icon.rotation,A.Arrow.Angle(target,player,1000,500,0)),0)
end)


test('optional node name sits alongside independent progress and changes with the target',function()
 local A=arrowSetup();local player=point(.2);local target=point(.4);target.kind='gather';target.name='Silverleaf'
 local snapshot={status='running',index=1,total=2,loop=true,lap=0}
 A.Arrow.Update(player,0,target,distance,snapshot);local f=A.Arrow.frame
 assert(f.nodeName);eq(f.nodeName:IsShown(),false);eq(f:GetHeight(),104)
 A.db.settings.arrowNodeName=true;A.Arrow.UpdateName(target)
 eq(f.nodeName:GetText(),'Silverleaf');eq(f.nodeName:IsShown(),true);eq(f:GetHeight(),124)
 target=point(.5);target.kind='gather';target.name='Peacebloom';snapshot.index=2
 A.Arrow.Update(player,0,target,distance,snapshot);eq(f.nodeName:GetText(),'Peacebloom');eq(f.progress:GetText(),'2/2 - Lap 1')
 A.db.settings.arrowProgress=false;A.Arrow.UpdateProgress(snapshot)
 eq(f.nodeName:IsShown(),true);eq(f.progress:IsShown(),false);eq(f:GetHeight(),104)
 A.db.settings.arrowNodeName=false;A.Arrow.UpdateName(target);eq(f.nodeName:IsShown(),false);eq(f:GetHeight(),84)
end)

test('arrow resolves old node-key-only gather points and uses honest unnamed waypoint labels',function()
 local A=arrowSetup();module('Follower',A)
 local n=A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',name='Silverleaf',materialID='gm:herb:402',source='confirmed'})
 local gather=point(.3);gather.kind='gather';gather.nodeKey=n.key
 local missing=point(.4);missing.kind='gather';missing.nodeKey='missing'
 local route={mapID=1,points={gather,missing,point(.5)}}
 local follower=A.Follower.New(route,point(.1),distance);A.db.settings.arrowNodeName=true
 local function draw() A.Arrow.Update(point(.1),0,follower:Target(),distance,follower:Snapshot()) end
 draw();local f=A.Arrow.frame;eq(f.nodeName:GetText(),'Silverleaf');assert(A.Arrow.TooltipText():find('Silverleaf',1,true))
 follower:Skip();draw();eq(f.nodeName:GetText(),'Gathering stop')
 follower:Skip();draw();eq(f.nodeName:GetText(),'Travel waypoint')
 follower:Pause();A.Arrow.Update(nil,nil,follower:Target(),distance,follower:Snapshot());eq(f.nodeName:IsShown(),true);eq(f.label:GetText(),'Paused')
 follower:Stop();draw();eq(f:IsShown(),false);eq(f.nodeName:IsShown(),false)
end)

test('generated corridor arrow shows its linked resource instead of the generic path label',function()
 local A=arrowSetup();module('Planner',A);module('Follower',A)
 local node=A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',name='Silverleaf',materialID='gm:herb:402',source='imported'})
 local route=assert(A.Planner.Generate({node},point(.2),distance,{coverageRadius=90,name='Test route'}))
 local f=A.Follower.New(route,point(.2),distance);local target=f:Target();eq(target.nodeKey,node.key)
 A.db.settings.arrowNodeName=true;A.Arrow.Update(point(.2),0,target,distance,f:Snapshot())
 eq(A.Arrow.frame.nodeName:GetText(),'Silverleaf');eq(f:Target(),target);eq(target.kind,'travel')
end)

test('terrain corridor arrow names the upcoming resource through bends and reversals',function()
 local A=arrowSetup()
 A.TerrainData={version=1,zones={[1]={w=5,h=5,widthYards=100,heightYards=100,rows={'2','2','2','+','2'},status='complete'}}}
 module('Terrain',A);module('Planner',A);module('Follower',A)
 local function d(a,b) return a and b and a.mapID==b.mapID and math.sqrt(((a.x-b.x)*100)^2+((a.y-b.y)*100)^2) or nil end
 A.Client.Size=function() return 100,100 end
 local left=A.Store.Observe(A.db,{mapID=1,x=.1,y=.1,kind='herb',name='Silverleaf',materialID='gm:herb:402',source='imported'})
 local right=A.Store.Observe(A.db,{mapID=1,x=.9,y=.1,kind='herb',name='Briarthorn',materialID='gm:herb:405',source='imported'})
 local route=assert(A.Planner.Generate({left,right},left,d,{coverageRadius=10,name='Terrain test'}))
 local f=A.Follower.New(route,left,d);A.db.settings.arrowNodeName=true
 f:Skip();local bend=f:Target();assert(bend.navigation and not bend.nodeKey)
 A.Arrow.Update(left,0,bend,d,f:Snapshot());eq(A.Arrow.frame.nodeName:GetText(),'Briarthorn')
 eq(f:Target(),bend);assert(A.Terrain.Segment(left,bend))
 assert(A.Arrow.TooltipText():find('Briarthorn',1,true))
 local index=f.index;f:Reverse();A.Arrow.Update(left,0,f:Target(),d,f:Snapshot())
 eq(A.Arrow.frame.nodeName:GetText(),'Silverleaf');eq(f.index,index);assert(A.Terrain.Validate(f.route))
 -- Toggling the optional label uses the same display target immediately.
 module('UIActions',A);A.follower=f;A.db.settings.arrowNodeName=false
 A.UIActions.Bind({Refresh=function() end}).arrowNodeName();eq(A.Arrow.frame.nodeName:GetText(),'Silverleaf')
 -- Direct resource guidance also has unnamed initial connector bends.
 local destination=A.Store.Copy(right);destination.nodeKey=right.key;destination.kind='gather'
 local direct=A.Follower.New({mapID=1,points={destination}},left,d)
 local connector=direct:Target();assert(connector.navigation)
 A.Arrow.Update(left,0,connector,d,direct:Snapshot());eq(A.Arrow.frame.nodeName:GetText(),'Briarthorn')
 eq(direct:Target(),connector);assert(A.Terrain.Segment(left,connector))
end)

test('corridor arrow reminds about zoom without changing coverage or legacy arrows',function()
 local A=arrowSetup();module('Follower',A)
 local route={mapID=1,loop=true,corridor=true,coverageRadius=180,points={point(.3),point(.6)}}
 local f=A.Follower.New(route,point(.1),distance);local zoom=0;A.Client.MinimapZoom=function() return zoom end
 local function draw() A.Arrow.Update(point(.1),0,f:Target(),distance,f:Snapshot()) end
 draw();local arrow=A.Arrow.frame;assert(arrow.zoomHint);eq(arrow.zoomHint:IsShown(),false)
 local height=arrow:GetHeight();zoom=2;draw();eq(arrow.zoomHint:IsShown(),true);assert(arrow:GetHeight()>height)
 assert(A.Arrow.TooltipText():find('180',1,true));near(f.route.coverageRadius,180);eq(f.index,1)
 zoom=0;draw();eq(arrow.zoomHint:IsShown(),false);eq(arrow:GetHeight(),height)
 A.Client.MinimapRadius=function() return 190 end;draw();eq(arrow.zoomHint:IsShown(),false)
 A.Client.MinimapRadius=function() return 170 end;draw();eq(arrow.zoomHint:IsShown(),true)
 assert(arrow.zoomHint:GetText():find('range',1,true));near(f.route.coverageRadius,180)
 f.route.corridor=nil;zoom=2;draw();eq(arrow.zoomHint:IsShown(),false)
end)
