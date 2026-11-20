local _,A=...
local J={};A.PlanningJob=J
local job
local function number(n)
 return not (issecretvalue and issecretvalue(n)) and type(n)=='number' and n==n and n>-math.huge and n<math.huge
end
local function clock()
 if type(debugprofilestop)=='function' then local ok,n=pcall(debugprofilestop);if ok and number(n) then return n end end
 if type(GetTime)=='function' then local ok,n=pcall(GetTime);if ok and number(n) then return n*1000 end end
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
 local start=clock();local previous,stalled=start,0
 if A.Terrain then A.Terrain.Checkpoint=function()
  local now=clock()
  if now>previous then previous=now;stalled=0 else stalled=stalled+1 end
  -- Count checkpoints only as a fallback for missing/frozen timers. Cheap
  -- geometry checks must not waste most of an otherwise usable frame slice.
  if stalled>=8 or now-start>=4 then coroutine.yield() end
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
