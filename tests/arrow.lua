local function arrowSetup()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,m in ipairs({'Store','Client','Skin','Arrow'}) do module(m,A) end
 A.db=A.Store.Open();A.Client.Size=function() return 1000,500 end
 return A
end
local function delta(a,b) return (b-a+math.pi)%(2*math.pi)-math.pi end

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
