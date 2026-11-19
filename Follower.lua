local _, A = ...
A.Follower={}
local runID=0
function A.Follower.New(route,start,distance,options)
 runID=runID+1
 local f={runID=runID,route=A.Store.Copy(route),index=1,direction=1,lap=0,status='running',distance=distance,visited={},collected={},gatherRecords={}}
 local function identity(p)
  if p.kind~='gather' then return nil end
  if p.resourceKind and p.materialID then return {kind=p.resourceKind,materialID=p.materialID,name=p.name,objectID=p.objectID} end
  for _,n in ipairs(A.db and A.db.nodes[p.mapID] or {}) do if n.key==p.nodeKey then return n end end
 end
 local function compatible(n,o)
  if not n or n.kind~=o.kind or n.objectID and o.objectID and n.objectID~=o.objectID then return false end
  local a=A.Resources and A.Resources.Info(n);local b=A.Resources and A.Resources.Info(o)
  if a and b then return a.id==b.id end
  return n.materialID==o.materialID or (n.name and n.name==o.name and (n.materialID:match('^node:') or o.materialID:match('^node:')))
 end
 function f:SetArrival(value)
  local n=tonumber(value)
  self.arrival=A.Store.Number(n) and math.max(5,math.min(40,n)) or 15
 end
 f:SetArrival(options and options.arrival)
 function f:Rejoin(position)
  local best,index
  for i,p in ipairs(self.route.points) do local d=self.distance(position,p)
   if A.Store.Number(d) and d>=0 and (not best or d<best) then best=d;index=i end
  end
  if not best or self.route.maxLink and best>self.route.maxLink then
   self.reason='Move nearer the farming area, or generate again from your current position.';return nil,self.reason
  end
  self.index=index
  if self.route.generated and self.route.loop and #self.route.points>2 then
   local nextPoint=self.route.points[self.index%#self.route.points+1]
   local previous=self.route.points[(self.index-2)%#self.route.points+1]
   local forward,back=self.distance(position,nextPoint),self.distance(position,previous)
   self.direction=back and forward and back<forward and -1 or 1
  end
  self.arrivedAt=nil;self.armed=nil;self.needsDeparture=nil;self.initialDistance=nil;self.transit=nil
  self.lapStart=self.lapStart or self.index;self.lapSeen=self.lapSeen or {};self.lapCount=self.lapCount or 0;return true
 end
 f:Rejoin(start)
 if #f.route.points==0 then f.status='complete'
 elseif route.maxLink and f.reason then f.status='suspended' end
 f.lapStart=f.lapStart or f.index;f.lapSeen=f.lapSeen or {};f.lapCount=f.lapCount or 0
 function f:Target() if self.status=='complete' or self.status=='stopped' then return nil end; return self.transit or self.route.points[self.index] end
 function f:Snapshot() return {status=self.status,index=self.index,total=#self.route.points,loop=self.route.loop,lap=self.lap,target=self:Target(),direction=self.direction,reason=self.reason,visited=self.visited} end
 function f:Pause() if self.status~='complete' and self.status~='stopped' then self.status='paused'; self.reason='Paused by you.' end end
 function f:Resume(position)
  if self.status~='paused' and self.status~='suspended' then return end
  if self.route.maxLink and not self:Rejoin(position) then return nil,self.reason end
  self.status='running';self.reason=nil;return true
 end
 function f:Stop() self.status='stopped'; self.reason=nil end
 local function step(self,now,position)
  local previous=self:Target()
  self.visited[self.index]=true
  if not self.lapSeen[self.index] then self.lapSeen[self.index]=true;self.lapCount=self.lapCount+1 end
  local nextIndex=self.index+self.direction
  if nextIndex<1 or nextIndex>#self.route.points then
   if not self.route.loop then self.status='complete'; return end
   nextIndex=nextIndex<1 and #self.route.points or 1
  end
  -- Coverage survives rejoining and reversing: each accounted stop completes
  -- this lap once, without requiring a second circuit to the old join point.
  if self.route.loop and self.lapCount>=#self.route.points then
   self.lap=self.lap+1;self.lapStart=nextIndex;self.visited={};self.lapSeen={};self.lapCount=0;self.collected={};self.gatherRecords={}
  end
  self.index=nextIndex;self.transit=nil; self.arrivedAt=position and A.Store.Copy(position) or nil
  self.initialDistance=position and self.distance(position,self:Target()) or nil
  local separation=previous and self.distance(previous,self:Target())
  self.needsDeparture=separation and separation<=1 or false
  self.armed=not position or not self.needsDeparture and self.initialDistance and self.initialDistance>self.arrival
 end
 function f:SkipCollected(position)
  if self.status~='running' then return end
  for _=1,#self.route.points do
   local p=self.route.points[self.index]
   if not p or p.kind~='gather' or not self.collected[self.index] then self.transit=nil;return end
   local nextIndex=self.index+self.direction
   if self.route.loop then nextIndex=(nextIndex-1)%#self.route.points+1 end
   local target=self.route.points[nextIndex]
   if target and self.route.maxLink then
    local d=position and self.distance(position,target)
    if not A.Store.Number(d) or d>self.route.maxLink then
     self.transit={mapID=p.mapID,x=p.x,y=p.y,kind='travel'};return
    end
   end
   step(self,nil,position)
   if self.status~='running' then return end
  end
 end
 function f:Advance(now,position)
  local previous=self:Target();step(self,now,position);self:SkipCollected(position or previous)
 end
 function f:ConfirmGather(o,knownNode)
  if self.status=='complete' or self.status=='stopped' or not A.Store.Position(o) or o.source~='confirmed' or type(o.materialID)~='string' then return nil end
  if o.routeRun and (o.routeRun~=self.runID or o.routeLap~=self.lap) then return nil end
  for _,record in ipairs(self.gatherRecords) do
   if o.sourceGUID and o.sourceGUID==record.sourceGUID or o.castGUID and o.castGUID==record.castGUID then return nil end
  end
  local best,index,ambiguous
  for i,p in ipairs(self.route.points) do if (not knownNode or p.nodeKey==knownNode.key) and compatible(identity(p),o) then
   local d=self.distance(o,p)
   if A.Store.Number(d) and d>=0 and d<=15 then
    if not best or d<best then best,index,ambiguous=d,i,false
    elseif d==best then ambiguous=true end
   end
  end end
  if not index or ambiguous or self.collected[index] then return nil end
  self.collected[index]=true;self.visited[index]=true
  local record=A.Store.Copy(o);record.routeNodeKey=self.route.points[index].nodeKey;self.gatherRecords[#self.gatherRecords+1]=record
  self:SkipCollected(o)
  return true
 end
 function f:RestoreGathers(previous)
  self.runID=previous.runID
  local function key(p) return p and string.format('%s:%s:%.17g:%.17g:%s',p.mapID,p.kind,p.x,p.y,p.nodeKey or '') end
  local seen,visited={},{};local anchor=key(previous.route.points[previous.lapStart])
  for i,p in ipairs(previous.route.points) do
   local id=key(p)
   if previous.lapSeen[i] then seen[id]=(seen[id] or 0)+1 end
   if previous.visited[i] then visited[id]=(visited[id] or 0)+1 end
  end
  self.lapSeen={};self.lapCount=0
  local anchored=false
  for i,p in ipairs(self.route.points) do
   local id=key(p)
   if not anchored and id==anchor then self.lapStart=i;anchored=true end
   if seen[id] and seen[id]>0 then self.lapSeen[i]=true;self.lapCount=self.lapCount+1;seen[id]=seen[id]-1 end
   if visited[id] and visited[id]>0 then self.visited[i]=true;visited[id]=visited[id]-1 end
  end
  self.gatherRecords=A.Store.Copy(previous.gatherRecords or {})
  for _,o in ipairs(self.gatherRecords) do for i,p in ipairs(self.route.points) do
   if o.routeNodeKey and p.nodeKey==o.routeNodeKey and compatible(identity(p),o) then
    self.collected[i]=true;self.visited[i]=true
   end
  end end
  self:SkipCollected(start)
 end
 function f:Skip() if self:Target() then self:Advance(nil,nil) end end
 function f:Reverse() self.direction=-self.direction;self.transit=nil end
 function f:Tick(position,now,gathering)
  if self.status=='complete' or self.status=='paused' or self.status=='stopped' then return end
  local p=self:Target(); local d=self.distance(position,p)
  if not d then self.status='suspended'; self.reason='Return to the route zone with readable coordinates.'; return end
  if self.status=='suspended' and self.route.maxLink then
   if not self:Rejoin(position) then return end
   p=self:Target();d=self.distance(position,p)
  end
  self.status='running'; self.reason=nil
  self:SkipCollected(position);p=self:Target();if not p then return end;d=self.distance(position,p)
  if not d then return end
  if self.arrivedAt and not self.armed then
   local moved=self.distance(position,self.arrivedAt)
   -- Coincident stops need a fresh entry; distinct nearby stops need only
   -- a little movement to avoid cycling while standing still in a cluster.
   if self.needsDeparture then
    if d>self.arrival+5 then self.armed=true end
   elseif moved and moved>=1 then self.armed=true end
  end
  if gathering then return end
  if self.arrivedAt and not self.armed then return end
  if d<=self.arrival then self:Advance(now,position) end
 end
 return f
end
