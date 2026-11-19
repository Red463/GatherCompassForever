local _, A = ...
A.Follower={}
function A.Follower.New(route,start,distance,options)
 local f={route=A.Store.Copy(route),index=1,direction=1,lap=0,status='running',distance=distance,visited={}}
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
  self.arrivedAt=nil;self.armed=nil;self.needsDeparture=nil;self.initialDistance=nil
  self.lapStart=self.index;self.lapSeen={};self.lapCount=0;self.visited={};return true
 end
 f:Rejoin(start)
 if #f.route.points==0 then f.status='complete'
 elseif route.maxLink and f.reason then f.status='suspended' end
 f.lapStart=f.lapStart or f.index;f.lapSeen=f.lapSeen or {};f.lapCount=f.lapCount or 0
 function f:Target() if self.status=='complete' or self.status=='stopped' then return nil end; return self.route.points[self.index] end
 function f:Snapshot() return {status=self.status,index=self.index,total=#self.route.points,loop=self.route.loop,lap=self.lap,target=self:Target(),direction=self.direction,reason=self.reason,visited=self.visited} end
 function f:Pause() if self.status~='complete' and self.status~='stopped' then self.status='paused'; self.reason='Paused by you.' end end
 function f:Resume(position)
  if self.status~='paused' and self.status~='suspended' then return end
  if self.route.maxLink and not self:Rejoin(position) then return nil,self.reason end
  self.status='running';self.reason=nil;return true
 end
 function f:Stop() self.status='stopped'; self.reason=nil end
 function f:Advance(now,position)
  local previous=self:Target()
  self.visited[self.index]=true
  if not self.lapSeen[self.index] then self.lapSeen[self.index]=true;self.lapCount=self.lapCount+1 end
  local nextIndex=self.index+self.direction
  if nextIndex<1 or nextIndex>#self.route.points then
   if not self.route.loop then self.status='complete'; return end
   nextIndex=nextIndex<1 and #self.route.points or 1
  end
  if self.route.loop and nextIndex==self.lapStart and self.lapCount>=#self.route.points then self.lap=self.lap+1;self.visited={};self.lapSeen={};self.lapCount=0 end
  self.index=nextIndex; self.arrivedAt=position and A.Store.Copy(position) or nil
  self.initialDistance=position and self.distance(position,self:Target()) or nil
  local separation=previous and self.distance(previous,self:Target())
  self.needsDeparture=separation and separation<=1 or false
  self.armed=not position or not self.needsDeparture and self.initialDistance and self.initialDistance>self.arrival
 end
 function f:Skip() if self:Target() then self:Advance(nil,nil) end end
 function f:Reverse() self.direction=-self.direction;self.lapStart=self.index;self.lapSeen={};self.lapCount=0 end
 function f:Tick(position,now,gathering)
  if self.status=='complete' or self.status=='paused' or self.status=='stopped' then return end
  local p=self:Target(); local d=self.distance(position,p)
  if not d then self.status='suspended'; self.reason='Return to the route zone with readable coordinates.'; return end
  if self.status=='suspended' and self.route.maxLink then
   if not self:Rejoin(position) then return end
   p=self:Target();d=self.distance(position,p)
  end
  self.status='running'; self.reason=nil
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
