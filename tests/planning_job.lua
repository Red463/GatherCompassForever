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

test('working profiling clocks use the frame time budget rather than stopping at eight cheap checkpoints',function()
 local A=setup();local before=debugprofilestop;local time,calls=0,0
 debugprofilestop=function() time=time+.05;return time end
 local done=false
 A.PlanJob(function() for _=1,100 do calls=calls+1;A.Terrain.Checkpoint() end end,function() done=true end)
 A.PlanningJob.Tick();assert(calls>=60 and calls<=90,'Frame budget stopped after only '..calls..' checkpoints');eq(done,false)
 A.PlanningJob.Tick();eq(calls,100);eq(done,true)
 debugprofilestop=before
end)

test('a profiling clock that stops after advancing still yields bounded work',function()
 local A=setup();local before=debugprofilestop;local reads,calls=0,0
 debugprofilestop=function() reads=reads+1;return reads==1 and 0 or 1 end
 A.PlanJob(function() for _=1,100 do calls=calls+1;A.Terrain.Checkpoint() end end)
 A.PlanningJob.Tick();assert(calls>0 and calls<100);A.PlanningJob.Cancel();debugprofilestop=before
end)
