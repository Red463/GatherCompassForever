local function setup()
 local A={Terrain={},Client={Position=function() return {mapID=1440} end}}
 module('PlanningJob',A);return A
end
test('terrain planning yields without a protected-call boundary and completes once',function()
 local A=setup();local calls,done=0,0;local before=debugprofilestop;debugprofilestop=function() return 0 end
 A.PlanJob(function() for i=1,40 do calls=calls+1;A.Terrain.Checkpoint() end;return 'route','ready' end,function(route,message) eq(route,'route');eq(message,'ready');done=done+1 end)
 eq(calls,0);A.PlanningJob.Tick();assert(calls>0 and calls<40);eq(done,0)
 for _=1,10 do A.PlanningJob.Tick() end;eq(calls,40);eq(done,1);eq(A.Terrain.Checkpoint,nil)
 debugprofilestop=before
end)
test('new planning jobs replace old work and zone changes cancel safely',function()
 local A=setup();local old,new=0,0
 A.PlanJob(function() old=old+1 end);A.PlanJob(function() new=new+1 end)
 A.PlanningJob.Tick();eq(old,0);eq(new,1)
 A.PlanJob(function() old=old+1 end);A.Client.Position=function() return {mapID=1439} end
 A.PlanningJob.Tick();eq(old,0);assert(A.status:find('zone changed',1,true))
end)
test('planning failures clear checkpoint and allow a retry',function()
 local A=setup();local reason
 A.PlanJob(function() error('bad terrain') end,nil,function(err) reason=err end)
 A.PlanningJob.Tick();assert(reason:find('bad terrain',1,true));eq(A.Terrain.Checkpoint,nil)
 local done=false;A.PlanJob(function() return true end,function() done=true end);A.PlanningJob.Tick();assert(done)
end)
