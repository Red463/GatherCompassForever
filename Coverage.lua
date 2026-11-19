local _,A=...
local C={};A.Coverage=C
C.MAX_HEAT_SAMPLES=4096
function C.HeatSpacing(heatRadius) return math.min(70,.6*heatRadius) end

-- Geometry below is in yards on both axes. A clamped projection also
-- handles single-point paths and the coincident ends of a return walk.
local function segment(a,b)
 local dx,dy=b.x-a.x,b.y-a.y
 return {a=a,b=b,dx=dx,dy=dy,length2=dx*dx+dy*dy,witnesses={}}
end
local function within(p,e,radius2)
 local x,y=p.x-e.a.x,p.y-e.a.y
 if e.length2>0 then
  local t=math.max(0,math.min(1,(x*e.dx+y*e.dy)/e.length2))
  x,y=x-t*e.dx,y-t*e.dy
 end
 return x*x+y*y<=radius2
end

local Index={}
function Index:Insert(e)
 local a,b=e.a,e.b
 local cell,r=self.cell,self.radius
 for x=math.floor((math.min(a.x,b.x)-r)/cell),math.floor((math.max(a.x,b.x)+r)/cell) do
  local column=self.grid[x]
  if not column then column={};self.grid[x]=column end
  for y=math.floor((math.min(a.y,b.y)-r)/cell),math.floor((math.max(a.y,b.y)+r)/cell) do
   local bucket=column[y]
   if not bucket then bucket={};column[y]=bucket end
   bucket[#bucket+1]=e
  end
 end
 return e
end
function Index:Find(p,skipA,skipB)
 local last=self.last
 if last and not last.retired and last~=skipA and last~=skipB and within(p,last,self.radius2) then return last end
 local column=self.grid[math.floor(p.x/self.cell)]
 local bucket=column and column[math.floor(p.y/self.cell)]
 if bucket then
  for _,edge in ipairs(bucket) do
   self.work=self.work+1
   if not edge.retired and edge~=skipA and edge~=skipB and within(p,edge,self.radius2) then self.last=edge;return edge end
  end
 end
end
function C.ClosedIndex(points,radius)
 local index=setmetatable({grid={},edges={},radius=radius,radius2=radius*radius,
  cell=math.max(60,radius),work=0},{__index=Index})
 for i,p in ipairs(points) do index.edges[i]=index:Insert(segment(p,points[i%#points+1])) end
 return index
end

local function length(a,b)
 local dx,dy=b.x-a.x,b.y-a.y
 return math.sqrt(dx*dx+dy*dy)
end

-- Each required location has a witness edge in this closed walk. A local
-- shortcut can change only its two incident edges. Transfer their witnesses
-- only after proving every one is still in range. All other proofs survive.
local function simplify(walk,radius,maxLink)
 local remaining=#walk
 local alternatives=C.ClosedIndex({},radius)
 for i,v in ipairs(walk) do
  v.prev=walk[(i-2)%remaining+1];v.next=walk[i%remaining+1]
  alternatives:Insert(v.edge)
 end
 local work=0
 for _=1,12 do
  local moves={}
  for i=2,#walk do
   local v=walk[i]
   if v.prev then
    local a,b=v.prev.p,v.next.p
    local direct=length(a,b)
    if direct<=maxLink then
     moves[#moves+1]={v=v,index=i,gain=length(a,v.p)+length(v.p,b)-direct}
    end
   end
  end
  table.sort(moves,function(a,b) if a.gain==b.gain then return a.index<b.index end;return a.gain>b.gain end)
  local removed=0
  for _,move in ipairs(moves) do
   local v=move.v;local prev,nextStep=v.prev,v.next
   if length(prev.p,nextStep.p)<=maxLink then
    local replacement=segment(prev.p,nextStep.p)
    local fits,transfers=true,{}
    for _,old in ipairs({prev.edge,v.edge}) do
     for _,p in ipairs(old.witnesses) do
      work=work+1
      if work+alternatives.work>250000 then return end
      if within(p,replacement,alternatives.radius2) then
       replacement.witnesses[#replacement.witnesses+1]=p
      else
       local other=alternatives:Find(p,prev.edge,v.edge)
       if not other then fits=false;break end
       transfers[#transfers+1]={edge=other,p=p}
      end
     end
     if not fits then break end
    end
    if fits then
     for _,t in ipairs(transfers) do t.edge.witnesses[#t.edge.witnesses+1]=t.p end
     prev.edge.retired=true;v.edge.retired=true
     prev.edge.witnesses=nil;v.edge.witnesses=nil
     alternatives:Insert(replacement)
     prev.edge=replacement;prev.next=nextStep;nextStep.prev=prev
     v.prev=nil;v.next=nil;v.edge=nil
     remaining=remaining-1;removed=removed+1
    end
   end
  end
  if remaining==1 or removed==0 then return end
 end
end

function C.Plan(valid,groups,component,trace,width,height,radius,maxLink)
 -- Both coverage and the finer heat/dedup grids need distinct integer
 -- indices. A positive native radius can still be unusably small.
 local heatRadius=.65*radius
 local smallestCell=math.min(math.max(radius,60),heatRadius,.45*C.HeatSpacing(heatRadius),35)
 if smallestCell<=0 or math.max(width,height)/smallestCell>=2^52 then return nil,'Zone or minimap distance data cannot represent this corridor.' end
 local positions={}
 for _,entry in ipairs(valid) do
  local n=entry.node
  positions[n]={x=n.x*width,y=n.y*height,node=n,key=entry.key}
 end
 local path={}
 for i,step in ipairs(trace) do path[i]=positions[groups[step.index].point] end
 for i,p in ipairs(path) do
  if length(p,path[i%#path+1])>maxLink then return nil,'A selected farming area requires a longer connection.' end
 end
 local index=C.ClosedIndex(path,radius)
 local excursions,pointCount={},#path
 local budgetReason='Too many locations to audit this corridor. Narrow the material filters.'
 for _,groupIndex in ipairs(component) do
  local group=groups[groupIndex];local anchor=positions[group.point]
  local outliers={}
  for _,node in ipairs(group.members) do
   local p=positions[node]
   p.required=true
   local edge=index:Find(p)
   if index.work>2000000 then return nil,budgetReason end
   if edge then edge.witnesses[#edge.witnesses+1]=p
   else outliers[#outliers+1]={p=p,distance=length(anchor,p)} end
  end
  -- A trip to the edge of a cluster can cover several nearer outliers.
  table.sort(outliers,function(a,b)
   if a.distance==b.distance then return a.p.key<b.p.key end
   return a.distance>b.distance
  end)
  for _,outlier in ipairs(outliers) do
   local p=outlier.p
   local edge=index:Find(p)
   if index.work>2000000 then return nil,budgetReason end
   if not edge then
    -- Group representatives can be farther than X from a member, including
    -- groups merged across cell boundaries. A return via the same anchor
    -- preserves both of its original short connections (including closure).
    if outlier.distance>maxLink then return nil,'A selected farming area requires a longer connection.' end
    pointCount=pointCount+2
    if pointCount>2000 then return nil,'This corridor has too many approaches. Narrow the material filters.' end
    edge=index:Insert(segment(anchor,p))
    local branches=excursions[groupIndex]
    if not branches then branches={};excursions[groupIndex]=branches end
    branches[#branches+1]={p=p,outward=edge}
   end
   edge.witnesses[#edge.witnesses+1]=p
  end
 end
 local walk={}
 for i,step in ipairs(trace) do
  local anchor=path[i];local branches=excursions[step.index]
  if branches then
   for _,branch in ipairs(branches) do
    walk[#walk+1]={p=anchor,edge=branch.outward}
    walk[#walk+1]={p=branch.p,edge=segment(branch.p,anchor)}
   end
   excursions[step.index]=nil
  end
  walk[#walk+1]={p=anchor,edge=index.edges[i]}
 end
 simplify(walk,radius,maxLink)
 local finalPath,points,verified={},{},{}
 local samples=0;local spacing=C.HeatSpacing(.65*radius)
 local step=walk[1]
 repeat
  local p=step.p;local n=p.node
  finalPath[#finalPath+1]=p
  if #finalPath>256 then return nil,'Too many corridor guidance stops. Narrow the material filters.' end
  local dest=step.next.p.node
  local d=math.sqrt(((dest.x-n.x)*width)^2+((dest.y-n.y)*height)^2)
  samples=samples+(d>0 and math.ceil(d/spacing) or 0)+1
  points[#points+1]={mapID=n.mapID,x=n.x,y=n.y,kind='travel',name='Farming corridor',nodeKey=p.key}
  for _,w in ipairs(step.edge.witnesses) do
   if not within(w,step.edge,index.radius2) then return nil,'Could not verify coverage of a selected location.' end
   verified[w]=true
  end
  step=step.next
 until step==walk[1]
 if samples>C.MAX_HEAT_SAMPLES then return nil,'This heat band is too narrow to draw the whole corridor. Narrow the material filters.' end
 local final=C.ClosedIndex(finalPath,radius)
 local keys,nodes={},{}
 for _,entry in ipairs(valid) do
  local p=positions[entry.node]
  if verified[p] or final:Find(p) then
   keys[entry.key]=true;nodes[#nodes+1]=entry.node
  elseif p.required then
   return nil,'Could not verify coverage of a selected location.'
  end
  if final.work>2000000 then return nil,budgetReason end
 end
 return {points=points,keys=keys,nodes=nodes,heatSpacing=spacing}
end
