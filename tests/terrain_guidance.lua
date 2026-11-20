local function unavailableTerrain()
 return {Route=function() return nil,'Terrain data unavailable.' end,Validate=function() return false,'Terrain data unavailable.' end,
  Allowed=function() return false end,Segment=function() return false end,Approach=function() return nil,'Terrain data unavailable.' end,Path=function() return nil,'Terrain data unavailable.' end,Distance=function() return nil end}
end

test('terrain unavailable suspends saved routes without exposing unsafe guidance or changing saved data',function()
 local A={Terrain=unavailableTerrain()};module('Store',A);module('Follower',A)
 local route={mapID=1,name='Saved route',points={point(.2),point(.8)},loop=true}
 local f=A.Follower.New(route,point(.1),distance)
 eq(f.status,'suspended');eq(f:Target(),nil);eq(#route.points,2);eq(route.points[1].x,.2)
 f:Tick(point(.2),1,false);eq(f.status,'suspended');eq(f:Target(),nil)
 f:Pause();eq(f:Resume(point(.2)),nil);eq(f.status,'suspended');eq(f:Target(),nil)
end)

test('resource nearest action preserves existing work when terrain has no safe guidance',function()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Editor','Recorder','Planner','Follower'}) do module(name,A) end
 moduleUI(A);A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
 A.UI.Build();A.UI.OpenRoutes();A.UI.SetTab('resources');local V=A.UI.resourceLibraryView
 V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1]);A.Terrain=unavailableTerrain()
 local plan={review=true};A.plan=plan;V.Guide()
 eq(A.follower,nil);eq(A.plan,plan);eq(plan.review,true);assert(A.UI.frame:IsShown());assert(A.status)
end)

local function terrainSetup(lines)
 local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
 lines=lines or {'11011','11011','11011','11111','11011'}
 local rows={};local w=#lines[1]
 for y,line in ipairs(lines) do
  local row={}
  for first=1,w,6 do
   local n=0;for x=first,first+5 do n=n*2+(line:sub(x,x)=='1' and 1 or 0) end
   row[#row+1]=alphabet:sub(n+1,n+1)
  end
  rows[y]=table.concat(row)
 end
 local A={TerrainData={version=1,zones={[1]={w=w,h=#lines,widthYards=100,heightYards=100,rows=rows,status='complete'}}}}
 module('Store',A);module('Terrain',A);module('Follower',A)
 local function p(x,y) return {mapID=1,x=(x-.5)/w,y=(y-.5)/#lines,kind='travel'} end
 local function d(a,b) if not a or not b or a.mapID~=b.mapID then return end;return math.sqrt(((a.x-b.x)*100)^2+((a.y-b.y)*100)^2) end
 return A,p,d
end

local function openLoop()
 local A,p,d=terrainSetup({'11111','11111','11111','11111','11111'})
 local route={mapID=1,generated=true,loop=true,maxLink=450,points={p(1,1),p(5,1),p(5,5),p(1,5)}}
 return A,p,d,A.Follower.New(route,p(1,1),d,{arrival=5})
end

test('automatic terrain recovery keeps the established route direction',function()
 local A,p,d,f=openLoop();f:Tick(p(1,1),0,false);eq(f.index,2);eq(f.direction,1)
 f:Tick(nil,1,false);eq(f.status,'suspended')
 local position={mapID=1,x=.85,y=.05}
 f:Tick(position,2,false);eq(f.status,'running');eq(f.direction,1);eq(f.index,2)
 assert(A.Terrain.Segment(position,f:Target()))
end)

test('terrain recovery does not send the player back to an already passed waypoint',function()
 local A,p,d,f=openLoop();f:Tick(p(1,1),0,false);f:Tick(p(5,1),1,false)
 eq(f.index,3);assert(f.lapSeen[2]);local lapCount=f.lapCount
 f:Tick(nil,2,false);eq(f.status,'suspended')
 local position={mapID=1,x=.85,y=.15}
 f:Tick(position,3,false);eq(f.status,'running');eq(f.index,3);eq(f.direction,1);eq(f.lapCount,lapCount)
 assert(A.Terrain.Segment(position,f:Target()))
end)

test('terrain resume keeps a manually reversed direction and the current leg',function()
 local A,p,d,f=openLoop();f:Tick(p(1,1),0,false);f:Reverse();eq(f.direction,-1);f:Pause()
 local position={mapID=1,x=.95,y=.15}
 assert(f:Resume(position));eq(f.status,'running');eq(f.direction,-1);eq(f.index,2)
 assert(A.Terrain.Segment(position,f:Target()))
end)

test('terrain follower joins and resumes using a safe connector through a ridge pass',function()
 local A,p,d=terrainSetup();local start=p(1,1);local route={mapID=1,points={p(5,1)},loop=false}
 local f=A.Follower.New(route,start,d,{arrival=5})
 eq(f.status,'running');assert(A.Terrain.Segment(start,f:Target()));assert(f:Target().y>start.y)
 f:Pause();assert(f:Resume(start));assert(A.Terrain.Segment(start,f:Target()))
 for i=1,20 do local t=f:Target();if not t then break end;assert(A.Terrain.Allowed(t));f:Tick(t,i,false) end
 eq(f.status,'complete');eq(#route.points,1)
end)

test('terrain arrival radius cannot cut a mandatory corner before the next segment is visible',function()
 local A,p,d=terrainSetup();local start=p(2,3)
 local f=A.Follower.New({mapID=1,points={start,p(2,4),p(4,4),p(4,3)}},start,d,{arrival=40})
 f:Tick(start,0,false);eq(f.index,2)
 local before=p(2,3.1);assert(not A.Terrain.Segment(before,f.route.points[3]))
 f:Tick(before,1,false);eq(f.index,2);assert(A.Terrain.Segment(before,f:Target()))
 f:Tick(p(2,4),2,false);eq(f.index,3)
end)

test('40 yard arrival with waypoints 20 yards apart waits for movement before advancing again',function()
 local A,p,d=terrainSetup({'11111','11111','11111','11111','11111'})
 local start=p(1,3);local f=A.Follower.New({mapID=1,points={start,p(2,3),p(5,3)}},start,d,{arrival=40})
 near(d(start,p(2,3)),20);f:Tick(start,0,false);eq(f.index,2)
 for i=1,100 do f:Tick(start,i*.1,false) end;eq(f.index,2)
 f:Tick({mapID=1,x=.105,y=.5},11,false);eq(f.index,2)
 local moved={mapID=1,x=.115,y=.5};assert(d(start,moved)>=1);f:Tick(moved,12,false);eq(f.index,3)
 assert(d(moved,p(2,3))<40);assert(A.Terrain.Segment(moved,f:Target()));eq(next(f.collected),nil)
end)

test('40 yard arrival waits for gathering when the nearby waypoint is already in range',function()
 local A,p,d=terrainSetup({'11111','11111','11111','11111','11111'})
 local start=p(1,3);local f=A.Follower.New({mapID=1,points={start,p(2,3),p(5,3)}},start,d,{arrival=40})
 f:Tick(start,0,false);local moved={mapID=1,x=.115,y=.5};assert(d(start,moved)>=1)
 f:Tick(moved,1,true);eq(f.index,2)
 f:Tick(moved,2,false);eq(f.index,3)
end)

test('terrain skip reverse and deviations keep the next target reachable by a safe segment',function()
 local A,p,d=terrainSetup();local start=p(1,1)
 local f=A.Follower.New({mapID=1,points={p(5,1),p(5,5)},loop=true},start,d,{arrival=5})
 f:Skip();assert(f:Target());assert(A.Terrain.Segment(start,f:Target()))
 f:Reverse();assert(A.Terrain.Segment(start,f:Target()))
 f:Tick(p(1,2),1,false);assert(A.Terrain.Segment(p(1,2),f:Target()))
 local target=f:Target();local index,direction=f.index,f.direction
 f:Tick(p(3,1),2,false);eq(f.status,'running');eq(f:Target(),target);eq(f.index,index);eq(f.direction,direction)
 f:Tick(p(1,1),3,false);eq(f.status,'running');assert(A.Terrain.Segment(p(1,1),f:Target()))
end)

test('blocked player cells preserve the current terrain connector and route progress',function()
 local A,p,d=terrainSetup();local start=p(1,1)
 local f=A.Follower.New({mapID=1,points={p(5,1)}},start,d,{arrival=5})
 local target,connector=f:Target(),f.connector;assert(connector)
 for i=1,3 do
  f:Tick(p(3,i),i,false);eq(f.status,'running');eq(f:Target(),target);eq(f.connector,connector);eq(f.index,1);eq(f.lap,0)
 end
end)

test('guidance can resume and recover at a blocked player cell without reversing or rewinding',function()
 local A,p,d=terrainSetup();local start=p(1,1)
 local f=A.Follower.New({mapID=1,points={p(5,1)}},start,d,{arrival=5})
 f:Reverse();f:Pause();assert(f:Resume(p(3,1)));eq(f.status,'running');assert(f:Target());eq(f.direction,-1)
 f:Tick(nil,1,false);eq(f.status,'suspended');eq(f:Target(),nil)
 f:Tick(p(3,2),2,false);eq(f.status,'running');assert(f:Target());eq(f.index,1);eq(f.direction,-1);eq(f.lap,0)
end)

test('guidance can join a planned route while the player is outside the terrain mask',function()
 local A,p,d=terrainSetup()
 local f=A.Follower.New({mapID=1,points={p(5,1)}},p(3,1),d,{arrival=5})
 eq(f.status,'running');assert(f:Target());eq(f:Target().x,.9)
end)

test('a blocked player cell does not trap guidance inside the waypoint arrival radius',function()
 local A,p,d=terrainSetup()
 local f=A.Follower.New({mapID=1,points={p(2,1),p(1,1)}},p(2,1),d,{arrival=25})
 f:Tick(p(3,1),1,false);eq(f.status,'running');eq(f.index,2);assert(f:Target())
end)

test('skipping a connector outside the mask discards its old detour',function()
 local A,p,d=terrainSetup()
 local f=A.Follower.New({mapID=1,loop=true,points={p(5,1),p(5,2)}},p(1,1),d,{arrival=5})
 assert(f.connector);local nextIndex=f.index==1 and 2 or 1
 f:Tick(p(3,1),1,true);eq(f.status,'running');f:Skip()
 eq(f.status,'running');eq(f.index,nextIndex);eq(f.connector,nil);eq(f:Target(),f.route.points[nextIndex])
end)

test('terrain follower suspends an unreachable initial connector and max-link uses walking distance',function()
 local A,p,d=terrainSetup({'11011','11011','11011','11011','11011'})
 local f=A.Follower.New({mapID=1,points={p(5,1)}},p(1,1),d)
 eq(f.status,'suspended');eq(f:Target(),nil)
 A,p,d=terrainSetup()
 f=A.Follower.New({mapID=1,maxLink=90,points={p(5,1)}},p(1,1),d)
 eq(f.status,'suspended');eq(f:Target(),nil)
end)

test('resource nearest action chooses a reachable spawn over a closer isolated one',function()
 local A,p,d=terrainSetup({'11011','11011','11011','11011','11011'})
 dofile('tests/wow.lua');fakeUI()
 for _,name in ipairs({'Client','Editor','Recorder','Planner'}) do module(name,A) end
 moduleUI(A);A.db=A.Store.Open();local player=p(2,1)
 A.Client.Position=function() return player end;A.Client.Distance=d;A.Client.Size=function() return 100,100 end
 for _,cell in ipairs({{4,1},{1,5}}) do local n=p(cell[1],cell[2]);n.kind='herb';n.materialID='gm:herb:402';n.name='Silverleaf';n.source='imported';A.Store.Observe(A.db,n) end
 A.UI.Build();A.UI.OpenRoutes();A.UI.SetTab('resources');local V=A.UI.resourceLibraryView
 V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1]);local pending
 A.PlanJob=function(work,done) pending={work=work,done=done};return true end
 V.Guide();eq(A.follower,nil);assert(pending);pending.done(pending.work())
 assert(A.follower);eq(A.follower.status,'running');assert(A.Terrain.Segment(player,A.follower:Target()))
 local target=A.follower.route.points[#A.follower.route.points]
 near(target.x,.1);near(target.y,.9);eq(target.materialID,'gm:herb:402');eq(target.resourceKind,'herb');assert(target.nodeKey)
end)

test('route generation and saved starts queue planning before publishing guidance and stop cancels it',function()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Editor','Recorder','Planner','Follower'}) do module(name,A) end
 moduleUI(A);A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 C_Minimap={GetViewRadius=function() return 200 end}
 A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
 A.UI.Build();A.UI.OpenRoutes();local pending
 A.PlanJob=function(work,done,onError) pending={work=work,done=done,onError=onError};return true end
 A.UI.actions.generateReview();eq(A.plan,nil);assert(pending)
 pending.done(pending.work());assert(A.plan);eq(A.follower,nil)
 pending=nil;A.UI.actions.start();eq(A.follower,nil);assert(pending)
 pending.done(pending.work());assert(A.follower)
 local cancelled=false;A.PlanningJob={Cancel=function() cancelled=true end};A.UI.actions.stop();assert(cancelled);eq(A.follower,nil)
end)

test('resource guidance uses a safe approach while preserving the blocked spawn identity',function()
 local A,p,d=terrainSetup({'11011'})
 dofile('tests/wow.lua');fakeUI()
 for _,name in ipairs({'Client','Editor','Recorder','Planner'}) do module(name,A) end
 moduleUI(A);A.db=A.Store.Open();local player=p(1,1)
 A.Client.Position=function() return player end;A.Client.Distance=d;A.Client.Size=function() return 100,100 end
 local n=A.Store.Observe(A.db,{mapID=1,x=.405,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
 A.UI.Build();A.UI.OpenRoutes();A.UI.SetTab('resources');local V=A.UI.resourceLibraryView
 V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1]);V.Guide()
 local target=A.follower.route.points[1];near(target.x,.3);near(target.resourcePosition.x,.405);eq(target.nodeKey,n.key)
 assert(A.Terrain.Segment(player,A.follower:Target()))
 local gathered={mapID=1,x=.405,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='confirmed'}
 assert(A.follower:ConfirmGather(gathered,n));eq(A.follower.collected[1],true)
end)

test('publishing an asynchronous saved start suspends when the player moved behind a barrier',function()
 local A,p,d=terrainSetup({'11011','11011','11011','11011','11011'})
 module('Selection',A);module('UIActions',A);A.db=A.Store.Open();local player=p(1,1)
 A.Client={Position=function() return player end,Distance=d}
 A.db.routes.saved={mapID=1,points={p(2,1)},loop=false};A.selectedRoute='saved'
 local U={frame={Hide=function() end},Refresh=function() end,Filter=function() return {} end,DisplayRoute=function() return A.follower and A.follower.route end}
 local pending;A.PlanJob=function(work,done) pending={work=work,done=done};return true end
 local actions=A.UIActions.Bind(U);actions.start();local f,reason=pending.work();assert(f)
 player=p(5,1);pending.done(f,reason)
 eq(A.follower.status,'suspended');eq(A.follower:Target(),nil)
end)

test('asynchronous node removal leaves the plan untouched until commit and rejects stale results',function()
 local A={};for _,name in ipairs({'Store','Planner','FarmingSession','Follower','Selection','UIActions'}) do module(name,A) end
 A.db=A.Store.Open();A.Client={Position=function() return point(.1) end,Distance=distance}
 local nodes={};for i,x in ipairs({.2,.4,.6}) do local n=point(x);n.key='n'..i;n.kind='herb';n.materialID='gm:herb:402';nodes[i]=n end
 local plan=assert(A.FarmingSession.New(nodes,point(.1),distance,{coverageRadius=100,viewRadius=120}));A.plan=plan;plan.selected='n2'
 local f=A.Follower.New(plan.route,point(.1),distance);f.session=plan;A.follower=f
 local U={Refresh=function() end,Filter=function() return {} end,DisplayRoute=function() return plan.route end}
 local pending;A.PlanJob=function(work,done) pending={work=work,done=done};return true end
 local actions=A.UIActions.Bind(U);local route,revision=plan.route,plan.revision
 actions.removeNode();assert(pending);eq(plan.route,route)
 local proposal,replacement,reason=pending.work();assert(proposal,reason);eq(plan.route,route);eq(plan.revision,revision);eq(plan.excluded.n2,nil)
 -- A completed calculation can be cancelled without invoking done. A newer
 -- edit also prevents an old callback from publishing a stale follower.
 assert(plan:Remove('n1',point(.1)));local newer=plan.route
 pending.done(proposal,replacement,reason)
 eq(plan.route,newer);eq(plan.excluded.n1,true);eq(plan.excluded.n2,nil);eq(A.follower,f)
end)

test('nearest resource search reports a budget limit instead of silently choosing a farther spawn',function()
 local A,p,d=terrainSetup();dofile('tests/wow.lua');fakeUI()
 for _,name in ipairs({'Client','Editor','Recorder','Planner'}) do module(name,A) end
 moduleUI(A);A.db=A.Store.Open();local player=p(2,1)
 A.Client.Position=function() return player end;A.Client.Distance=d;A.Client.Size=function() return 100,100 end
 for _,cell in ipairs({{4,1},{1,5}}) do local n=p(cell[1],cell[2]);n.kind='herb';n.materialID='gm:herb:402';n.name='Silverleaf';n.source='imported';A.Store.Observe(A.db,n) end
 A.UI.Build();A.UI.OpenRoutes();A.UI.SetTab('resources');local V=A.UI.resourceLibraryView
 V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1])
 local path=A.Terrain.Path;A.Terrain.Path=function(a,b,options) return path(a,b,b.x>.5 and {budget=0} or options) end
 V.Guide();eq(A.follower,nil);assert(A.status:find('budget',1,true))
end)

test('cancelling a yielded resume preserves the live paused follower and publishes only a completed draft',function()
 local A,p,d=terrainSetup();module('PlanningJob',A);module('UIActions',A)
 A.db=A.Store.Open();local player=p(1,1);A.Client={Position=function() return player end,Distance=d}
 local f=A.Follower.New({mapID=1,points={p(5,1)}},player,d);f:Pause();A.follower=f
 local session={route=f.route};local filter={kind='herb',materials={['gm:herb:402']=true}}
 f.session=session;f.markerFilter=filter
 local connector,position,index,reason=f.connector,f.position,f.index,f.reason;assert(connector)
 local U={Refresh=function() end,Filter=function() return filter end,DisplayRoute=function() return A.follower.route end}
 local actions=A.UIActions.Bind(U);local path,yielded=A.Terrain.Path,false
 A.Terrain.Path=function(a,b,options)
  if not yielded then yielded=true;coroutine.yield() end
  return path(a,b,options)
 end
 player=p(1,2);actions.pause();A.PlanningJob.Tick();assert(yielded)
 eq(A.follower,f);eq(f.status,'paused');eq(f.connector,connector);eq(f.position,position);eq(f.index,index);eq(f.reason,reason)
 A.PlanningJob.Cancel();A.PlanningJob.Tick()
 eq(A.follower,f);eq(f.connector,connector);eq(f.position,position);eq(f.status,'paused')
 actions.pause();for _=1,20 do A.PlanningJob.Tick() end
 assert(A.follower~=f);eq(A.follower.status,'running');eq(f.status,'paused');eq(A.follower.session,session);eq(A.follower.distance,d);eq(A.follower.markerFilter,filter)
 assert(A.Terrain.Segment(player,A.follower:Target()))
end)

test('resume drafts cannot overwrite a newer arrival setting or skipped waypoint',function()
 for _,change in ipairs({'arrival','skip','replacement'}) do
  local A={};for _,name in ipairs({'Store','Follower','UIActions'}) do module(name,A) end
  A.db=A.Store.Open();A.Client={Position=function() return point(.1) end,Distance=distance}
  local f=A.Follower.New({mapID=1,points={point(.2),point(.4)}},point(.1),distance);f:Pause();A.follower=f
  local U={Refresh=function() end};local pending
  A.PlanJob=function(work,done) pending={work=work,done=done};return true end
  local actions=A.UIActions.Bind(U);actions.pause();local draft,reason=pending.work();assert(draft,reason)
  if change=='arrival' then f:SetArrival(25)
  elseif change=='skip' then f:Skip()
  else A.follower={status='running'} end
  local current=A.follower;pending.done(draft,reason)
  eq(A.follower,current)
  if change~='replacement' then eq(f.status,'paused');if change=='arrival' then eq(f.arrival,25) else eq(f.index,2) end end
 end
end)
