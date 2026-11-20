local _,A=...
local J={};A.PlanningJob=J
local job
local function clock()
 if type(debugprofilestop)=='function' then local ok,n=pcall(debugprofilestop);if ok and type(n)=='number' then return n end end
 if type(GetTime)=='function' then local ok,n=pcall(GetTime);if ok and type(n)=='number' then return n*1000 end end
 return 0
end
function J.Cancel(reason)
 job=nil
 if A.Terrain then A.Terrain.Checkpoint=nil end
 if reason then A.status=reason end
end
function A.PlanJob(work,done,failed)
 J.Cancel()
 local p=A.Client.Position()
 job={thread=coroutine.create(work),done=done,failed=failed,mapID=p and p.mapID}
 A.status='Planning terrain-safe route...'
 return true
end
function J.Tick()
 if not job then return false end
 local active=job;local p=A.Client.Position()
 if not p or p.mapID~=active.mapID then J.Cancel('Planning cancelled: zone changed or player position is unavailable.');return true end
 local start,calls=clock(),0
 if A.Terrain then A.Terrain.Checkpoint=function()
  calls=calls+1
  if calls>=8 or clock()-start>=4 then coroutine.yield() end
 end end
 -- resume catches errors without placing a protected call around yielding work.
 local ok,a,b,c=coroutine.resume(active.thread)
 if A.Terrain then A.Terrain.Checkpoint=nil end
 if job~=active then return true end
 if not ok then
  job=nil;A.status='Route planning stopped: '..tostring(a)
  if active.failed then active.failed(A.status) end
 elseif coroutine.status(active.thread)=='dead' then
  job=nil;if active.done then active.done(a,b,c) end
 end
 return not job
end
