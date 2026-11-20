local function traceSetup()
 local A={TerrainData={version=1,build=70959,zones={[1]={w=5,h=5,widthYards=100,heightYards=100,rows={'2','2','2','+','2'},status='complete'}}}}
 for _,name in ipairs({'Store','Client','Terrain','Follower','GuidanceTrace'}) do module(name,A) end
 A.db=A.Store.Open();A.messages={};A.Print=function(s) A.messages[#A.messages+1]=s end
 local function p(x,y) return {mapID=1,x=x,y=y} end
 local function d(a,b) if not a or not b or a.mapID~=b.mapID then return nil end;return math.sqrt(((a.x-b.x)*100)^2+((a.y-b.y)*100)^2) end
 local f=A.Follower.New({mapID=1,points={p(.9,.1)},loop=false,maxLink=450},p(.9,.9),d,{arrival=5})
 return A,A.GuidanceTrace,f,p
end

test('guidance trace is opt-in and captures position dropout plus unchanged recovery',function()
 local A,D,f,p=traceSetup();D.Sample(f,p(.9,.9),nil,0);eq(A.db.guidanceTrace,nil)
 D.Start();D.Sample(f,p(.9,.9),nil,0)
 f:Tick(nil,1,false);D.Sample(f,nil,'coordinates-protected',1)
 local events=A.db.guidanceTrace.events;local drop=events[#events]
 eq(drop.event,'dropout');eq(drop.cause,'position-unavailable');eq(drop.positionReason,'coordinates-protected')
 eq(drop.lastPosition.mapID,1);near(drop.lastPosition.x,.9);eq(drop.index,1);eq(drop.direction,1)
 local count=#events;for i=1,30 do D.Sample(f,nil,'coordinates-protected',1+i*.01) end;eq(#events,count)
 f:Tick(p(.9,.8),3,true);D.Sample(f,p(.9,.8),nil,3)
 eq(events[#events].event,'recovered');eq(events[#events].index,drop.index);eq(events[#events].direction,drop.direction)
 local report=D.Text();assert(report:find('coordinates-protected',1,true));assert(report:find('recovered',1,true));assert(report:find('70959',1,true))
 D.Stop();D.Sample(nil,nil,nil,4);eq(#events,count+1)
end)

test('guidance trace distinguishes map changes and search budgets',function()
 for _,failure in ipairs({'map-changed','path-budget'}) do
  local A,D,f,p=traceSetup();D.Start();D.Sample(f,p(.9,.9),nil,0)
  local position
  if failure=='map-changed' then position={mapID=2,x=.9,y=.9}
  else position=p(.1,.1);A.Terrain.Path=function() return nil,'budget' end end
  f:Tick(position,1,false);D.Sample(f,position,nil,1)
  local e=A.db.guidanceTrace.events[#A.db.guidanceTrace.events];eq(e.event,'dropout');eq(e.cause,failure)
 end
end)

test('guidance trace does not report a dropout for a readable blocked mask cell',function()
 local A,D,f,p=traceSetup();D.Start();D.Sample(f,p(.9,.9),nil,0)
 local position=p(.5,.1);eq(A.Terrain.Allowed(position),false)
 f:Tick(position,1,false);D.Sample(f,position,nil,1)
 eq(f.status,'running');assert(f:Target());eq(#A.db.guidanceTrace.events,1)
 -- The mask remains useful diagnostic context when guidance really is paused.
 f:Pause();D.Sample(f,position,nil,2)
 local e=A.db.guidanceTrace.events[2];eq(e.event,'paused');eq(e.allowed,false);eq(e.cellX,2);eq(e.cellY,0)
end)

test('guidance history stays bounded and saved reports remain readable after reload',function()
 local A,D,f,p=traceSetup();D.Start()
 for i=1,100 do f.status=i%2==0 and 'running' or 'suspended';f.failureCode='path-budget';D.Sample(f,p(.9,.9),nil,i) end
 assert(#A.db.guidanceTrace.events<=40);local saved=A.Store.Copy(A.db.guidanceTrace)
 local B,E=traceSetup();B.db.guidanceTrace=saved;assert(E.Text():find('path-budget',1,true));eq(E.active,false)
 E.Report();assert(#B.messages>0)
end)

test('client position failures expose safe diagnostic reasons without restricted coordinates',function()
 local A={};module('Store',A);module('Client',A)
 local oldMap,oldSecret=C_Map,issecretvalue;local secret={}
 C_Map={GetBestMapForUnit=function() return 1 end,GetPlayerMapPosition=function() return {GetXY=function() return secret,.3 end} end}
 issecretvalue=function(v) return v==secret end
 local p,reason=A.Client.Position();eq(p,nil);eq(reason,'coordinates-protected')
 issecretvalue=nil;C_Map.GetPlayerMapPosition=function() return nil end
 p,reason=A.Client.Position();eq(p,nil);eq(reason,'position-unavailable')
 C_Map.GetPlayerMapPosition=function() error('native API failure') end
 p,reason=A.Client.Position();eq(p,nil);eq(reason,'position-api-error')
 C_Map=nil;p,reason=A.Client.Position();eq(p,nil);eq(reason,'map-api-unavailable')
 C_Map=oldMap;issecretvalue=oldSecret
end)
