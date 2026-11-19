local _, A = ...
A.Recorder={}
function A.Recorder.New(mapID,distance)
 local r={mapID=mapID,points={},distance=distance or A.Client.Distance}
 function r:Sample(p,now)
  if self.paused then return end
  if not A.Store.Position(p) or p.mapID~=self.mapID then self.paused=true; self.reason='Position lost or zone changed. Return to the last point to resume.'; return end
  if self.lastTime and now-self.lastTime<.5 then return end
  self.lastTime=now
  local last=self.points[#self.points]
  if last then
   local d=self.distance(last,p)
   if not d then self.paused=true; self.reason='Distance unavailable.'; return end
   if d<5 then return end
   if d>100 then self.paused=true; self.reason='Movement gap detected. Return to the last point to resume.'; return end
  end
  if #self.points>=2000 then self.paused=true; self.reason='2,000-point recording limit reached. Save this route.'; return end
  local q=A.Store.Copy(p); q.kind='travel'; self.points[#self.points+1]=q
 end
 function r:Resume(p)
  local last=self.points[#self.points]
  if not A.Store.Position(p) or p.mapID~=self.mapID then return false end
  if last then local d=self.distance(last,p); if not d or d>5 then return false end end
  self.paused=false; self.reason=nil; self.lastTime=nil; return true
 end
 function r:Finish(name)
  if #self.points==0 then return nil,'No valid path points recorded.' end
  -- Global Ramer-Douglas-Peucker: each final chord is checked against EVERY
  -- original sample it replaces. Local triple removal can cut wide curves.
  local keep={[1]=true,[#self.points]=true}; local stack={{1,#self.points}}
  while #stack>0 do
   local range=table.remove(stack); local first,last=range[1],range[2]
   local a,b=self.points[first],self.points[last]; local ab=self.distance(a,b)
   local far,index=3,nil
   for i=first+1,last-1 do
    local p=self.points[i]; local ap,bp=self.distance(a,p),self.distance(b,p)
    local d
    if not ab or not ap or not bp then d=math.huge
    elseif ab==0 then d=ap
    else
     local along=(ap*ap+ab*ab-bp*bp)/(2*ab)
     if along<0 then d=ap elseif along>ab then d=bp else d=math.sqrt(math.max(0,ap*ap-along*along)) end
    end
    if d>far then far,index=d,i end
   end
   if index then keep[index]=true; stack[#stack+1]={first,index}; stack[#stack+1]={index,last} end
  end
  local points={}; for i,p in ipairs(self.points) do if keep[i] then points[#points+1]=A.Store.Copy(p) end end
  return {name=name,mapID=self.mapID,points=points,loop=false,recorded=true}
 end
 return r
end
