local _,A=...
local C={};A.Corridor=C
local S=A.Store
local function nodeKey(n) return type(n.key)=='string' and n.key or string.format('%.17g:%.17g:%s',n.x,n.y,tostring(n.materialID)) end
local function optimize(trace,edges)
 local function link(a,b) if a==b then return 0 end;return edges[a][b] end
 local function prune()
  local i=2 -- Keep the nearest starting gather fixed.
  while i<=#trace do
   local p=trace[i];local a,b=trace[i-1].index,trace[i%#trace+1].index
   local shortcut=link(a,b)
   if p.travel and shortcut and shortcut<=link(a,p.index)+link(p.index,b)+.000001 then table.remove(trace,i) else i=i+1 end
  end
 end
 prune()
 -- Best-improvement 2-opt over a feasible closed walk. Cached graph edges
 -- enforce the same 450-yard limit for swaps and final closure; branch
 -- returns remain when no short alternative connects their neighbours.
 for _=1,32 do
  local gain,left,right=.000001
  for i=1,#trace-2 do
   local a,b=trace[i].index,trace[i+1].index
   for j=i+2,#trace do
    local c,d=trace[j].index,trace[j%#trace+1].index
    local ac,bd=link(a,c),link(b,d)
    if ac and bd then
     local improvement=link(a,b)+link(c,d)-ac-bd
     if improvement>gain then gain,left,right=improvement,i+1,j end
    end
   end
  end
  if not left then break end
  while left<right do trace[left],trace[right]=trace[right],trace[left];left=left+1;right=right-1 end
  prune()
 end
end
local function terrainGenerate(nodes,start,options)
 local T=A.Terrain
 local zone,reason=T.Zone(start.mapID)
 if not zone then return nil,'Terrain routing unavailable: '..tostring(reason) end
 local width,height=zone.widthYards,zone.heightYards
 if not S.Number(width) or not S.Number(height) or width<=0 or height<=0 then return nil,'Terrain zone dimensions are unavailable.' end
 local function straight(a,b) return math.sqrt(((a.x-b.x)*width)^2+((a.y-b.y)*height)^2) end
 local maxLink,cell=450,120
 local valid,total={},0
 for i,n in ipairs(nodes) do
  if S.Position(n) and n.mapID==start.mapID then
   total=total+1
   local p=T.Approach(n,30)
   if p and (not options.coverageRadius or straight(n,p)<=options.coverageRadius) then
    valid[#valid+1]={node=n,point=p,key=nodeKey(n),distance=straight(start,p)}
   end
  end
  if i%64==0 and T.Checkpoint then T.Checkpoint() end
 end
 if #valid==0 then return nil,'No selected spawn points have a safe terrain approach.' end
 table.sort(valid,function(a,b) if a.distance==b.distance then return a.key<b.key end;return a.distance<b.distance end)
 local first,nearest
 for i,e in ipairs(valid) do
  if e.distance>maxLink or nearest and e.distance>nearest then break end
  local path,d=T.Path(start,e.point)
  if path then if d<=maxLink and (not nearest or d<nearest) then first,nearest=e,d end
  elseif d=='budget' then return nil,'Terrain routing exceeded its search budget. Narrow the material filters or move closer.' end
  if i%64==0 and T.Checkpoint then T.Checkpoint() end
 end
 if not first then return nil,'No selected nodes have a safe nearby walking connection.' end
 -- Cell sharing alone cannot merge opposite sides of a wall. Representatives
 -- are actual permitted approaches, and every member has a direct safe spoke.
 local grid,groups={},{}
 for i,e in ipairs(valid) do
  local p=e.point;local key=math.floor(p.x*width/cell)..':'..math.floor(p.y*height/cell)
  local bucket=grid[key];if not bucket then bucket={};grid[key]=bucket end
  local group
  for _,g in ipairs(bucket) do if T.Segment(g.point,p) then group=g;break end end
  if not group then group={point=p,entry=e,members={}};bucket[#bucket+1]=group;groups[#groups+1]=group end
  group.members[#group.members+1]=e
  if e==first then group.point=p;group.entry=e;group.first=true end
  if i%64==0 and T.Checkpoint then T.Checkpoint() end
 end
 -- A changed root representative must still see all its group members.
 -- Rebuild its group if the nearest approach is around a corner from one.
 local root
 for _,g in ipairs(groups) do if g.first then root=g;break end end
 for i=#root.members,1,-1 do local e=root.members[i]
  if not T.Segment(root.point,e.point) then
   table.remove(root.members,i);groups[#groups+1]={point=e.point,entry=e,members={e}}
  end
 end
 table.sort(groups,function(a,b)
  if a==root then return b~=root end;if b==root then return false end
  local da,db=straight(start,a.point),straight(start,b.point)
  if da==db then return a.entry.key<b.entry.key end;return da<db
 end)
 -- Fine mask searches are much costlier than the old scalar metric. Keep the
 -- local area budget small; mandatory path geometry has no such point cap.
 while #groups>40 do table.remove(groups) end
 local edges={};for i=1,#groups do edges[i]={} end
 for i=1,#groups do for j=i+1,#groups do
  if straight(groups[i].point,groups[j].point)<=maxLink then
   local path,d=T.Path(groups[i].point,groups[j].point)
   if path then if d<=maxLink then edges[i][j]=d;edges[j][i]=d end
   elseif d=='budget' then return nil,'Terrain routing exceeded its search budget. Narrow the material filters or move closer.' end
  end
 end;if T.Checkpoint then T.Checkpoint() end end
 local component={[1]=true};local queue={1};local head=1
 while queue[head] do local i=queue[head];head=head+1
  for j in pairs(edges[i]) do if not component[j] then component[j]=true;queue[#queue+1]=j end end
 end
 local costs,parent,used,tree={[1]=0},{},{},{}
 for i=1,#groups do tree[i]={} end
 for _=1,#queue do
  local best
  for i in ipairs(groups) do if component[i] and not used[i] and costs[i] and (not best or costs[i]<costs[best] or costs[i]==costs[best] and i<best) then best=i end end
  if not best then break end;used[best]=true
  if parent[best] then tree[parent[best]][#tree[parent[best]]+1]=best;tree[best][#tree[best]+1]=parent[best] end
  for j,d in pairs(edges[best]) do if not used[j] and (not costs[j] or d<costs[j]) then costs[j]=d;parent[j]=best end end
 end
 local trace,visited={},{}
 local function walk(i)
  visited[i]=true;trace[#trace+1]={index=i}
  table.sort(tree[i],function(a,b) if edges[i][a]==edges[i][b] then return a<b end;return edges[i][a]<edges[i][b] end)
  for _,j in ipairs(tree[i]) do if not visited[j] then walk(j);trace[#trace+1]={index=i,travel=true} end end
 end
 walk(1);if #trace>1 then table.remove(trace) end
 optimize(trace,edges)
 local includedNodes,keys={},{}
 for _,i in ipairs(queue) do for _,e in ipairs(groups[i].members) do includedNodes[#includedNodes+1]=e.node;keys[e.key]=true end end
 local points={}
 for _,step in ipairs(trace) do
  local g=groups[step.index];local p,n=g.point,g.entry.node
  points[#points+1]={mapID=start.mapID,x=p.x,y=p.y,kind=step.travel and 'travel' or 'gather',mandatory=true,
   nodeKey=g.entry.key,name=not step.travel and n.name or nil,density=#g.members,resourceKind=n.kind,materialID=n.materialID,objectID=n.objectID}
 end
 local route={mapID=start.mapID,loop=true,generated=true,points=points,maxLink=maxLink,width=width,height=height,
  includedKeys=keys,includedCount=#includedNodes,omittedCount=total-#includedNodes,areaCount=#queue}
 if options.coverageRadius then
  local plan
  plan,reason=A.Coverage.TerrainPlan(route,valid,groups,queue,options.coverageRadius)
  if not plan then return nil,reason end
  route=plan.route;includedNodes=plan.nodes
  route.includedCount=#includedNodes;route.omittedCount=total-#includedNodes
  route.minimapViewRadius=options.viewRadius
 else
  route,reason=T.Route(route)
  if not route then return nil,'Terrain route expansion failed: '..tostring(reason) end
 end
 route.name=options.name or A.Planner.Name(includedNodes,start.mapID,options)
 return route,'Local corridor: '..route.includedCount..' of '..total..' selected locations have safe terrain approaches.'
end
function C.Generate(nodes,start,distance,options)
 options=options or {}
 local radius=options.coverageRadius
 if radius~=nil and (not S.Number(radius) or radius<=0) then return nil,'A readable corridor coverage radius is required.' end
 if not S.Position(start) then return nil,'A readable player position is required.' end
 if #nodes>20000 then return nil,'Too many candidates in this zone. Narrow the material filters.' end
 if A.Terrain then return terrainGenerate(nodes,start,options) end
 local maxLink=450;local cell=120;local valid={}
 local function measure(a,b)
  local d=distance(a,b);if S.Number(d) and d>=0 then return d end
 end
 for _,n in ipairs(nodes) do if S.Position(n) and n.mapID==start.mapID then
  local d=measure(start,n);if not d then return nil,'Zone distance data is unavailable.' end
  valid[#valid+1]={node=n,distance=d,key=nodeKey(n)}
 end end
 if #valid==0 then return nil,'No spawn points match these filters in this zone.' end
 table.sort(valid,function(a,b) if a.distance==b.distance then return a.key<b.key end;return a.distance<b.distance end)
 if valid[1].distance>maxLink then return nil,'No selected nodes nearby. Move closer to a matching area or widen your material selection.' end
 local origin={mapID=start.mapID,x=0,y=0}
 local width=measure(origin,{mapID=start.mapID,x=1,y=0});local height=measure(origin,{mapID=start.mapID,x=0,y=1})
 if not width or not height or width<=0 or height<=0 then return nil,'Zone distance data is unavailable.' end
 local grid,groups={},{}
 for _,entry in ipairs(valid) do
  local n=entry.node;local key=math.floor(n.x*width/cell)..':'..math.floor(n.y*height/cell)
  local g=grid[key]
  if not g then g={key=key,members={},nearest=entry.distance,sx=0,sy=0};grid[key]=g;groups[#groups+1]=g end
  g.members[#g.members+1]=n;g.sx=g.sx+n.x;g.sy=g.sy+n.y
 end
 table.sort(groups,function(a,b) if a.nearest==b.nearest then return a.key<b.key end;return a.nearest<b.nearest end)
 while #groups>96 do table.remove(groups) end
 for _,g in ipairs(groups) do
  local centre={mapID=start.mapID,x=g.sx/#g.members,y=g.sy/#g.members};local best
  for _,n in ipairs(g.members) do local d=measure(n,centre);if not d then return nil,'Zone distance data is unavailable.' end
   if not best or d<best then best=d;g.point=n end
  end
 end
 -- The first farming area always uses the player's actual nearest candidate.
 local first=valid[1].node;local rootKey=math.floor(first.x*width/cell)..':'..math.floor(first.y*height/cell)
 for i,g in ipairs(groups) do if g.key==rootKey then g.point=first;groups[1],groups[i]=g,groups[1];break end end
 -- Merge nearly coincident representatives at cell boundaries.
 local compact={}
 for _,g in ipairs(groups) do
  local into
  for _,other in ipairs(compact) do local d=measure(g.point,other.point);if not d then return nil,'Zone distance data is unavailable.' end;if d<=60 then into=other;break end end
  if into then for _,n in ipairs(g.members) do into.members[#into.members+1]=n end else compact[#compact+1]=g end
 end
 groups=compact
 local edges={}
 for i=1,#groups do edges[i]={} end
 for i=1,#groups do for j=i+1,#groups do
  local d=measure(groups[i].point,groups[j].point);if not d then return nil,'Zone distance data is unavailable.' end
  if d<=maxLink then edges[i][j]=d;edges[j][i]=d end
 end end
 local component={[1]=true};local queue={1};local head=1
 while queue[head] do local i=queue[head];head=head+1;for j in pairs(edges[i]) do if not component[j] then component[j]=true;queue[#queue+1]=j end end end
 local costs,parent,used,tree={[1]=0},{},{},{}
 for i=1,#groups do tree[i]={} end
 -- Prim on the local component: no optimization or closure can add a long chord.
 for _=1,#queue do
  local best
  for i in ipairs(groups) do if component[i] and not used[i] and costs[i] and (not best or costs[i]<costs[best] or costs[i]==costs[best] and i<best) then best=i end end
  if not best then break end;used[best]=true
  if parent[best] then tree[parent[best]][#tree[parent[best]]+1]=best;tree[best][#tree[best]+1]=parent[best] end
  for j,d in pairs(edges[best]) do if component[j] and not used[j] and (not costs[j] or d<costs[j]) then costs[j]=d;parent[j]=best end end
 end
 local trace={};local visited={}
 local function walk(i)
  visited[i]=true;trace[#trace+1]={index=i}
  table.sort(tree[i],function(a,b) if edges[i][a]==edges[i][b] then return a<b end;return edges[i][a]<edges[i][b] end)
  for _,j in ipairs(tree[i]) do if not visited[j] then walk(j);trace[#trace+1]={index=i,travel=true} end end
 end
 walk(1)
 if #trace>1 then table.remove(trace) end
 optimize(trace,edges)
 if radius then
  local plan,reason=A.Coverage.Plan(valid,groups,queue,trace,width,height,radius,maxLink)
  if not plan then return nil,reason end
  local count=#plan.nodes
  local route={name=options.name or A.Planner.Name(plan.nodes,start.mapID,options),mapID=start.mapID,loop=true,generated=true,
   corridor=true,coverageRadius=radius,minimapViewRadius=options.viewRadius,heatRadius=.65*radius,heatSpacing=plan.heatSpacing,
   points=plan.points,includedKeys=plan.keys,includedCount=count,omittedCount=#valid-count,
   areaCount=#queue,maxLink=maxLink,width=width,height=height}
  return route,'Local corridor: '..count..' of '..#valid..' selected locations covered.'
 end
 local points,included,includedNodes={},0,{}
 for _,g in ipairs(queue) do for _,n in ipairs(groups[g].members) do included=included+1;includedNodes[#includedNodes+1]=n end end
 for _,step in ipairs(trace) do local g=groups[step.index];local n=g.point
  points[#points+1]={mapID=start.mapID,x=n.x,y=n.y,kind=step.travel and 'travel' or 'gather',nodeKey=n.key or nodeKey(n),name=not step.travel and n.name or nil,density=#g.members,
   resourceKind=n.kind,materialID=n.materialID,objectID=n.objectID}
 end
 local route={name=options.name or A.Planner.Name(includedNodes,start.mapID,options),mapID=start.mapID,loop=true,generated=true,points=points,
  maxLink=maxLink,includedCount=included,omittedCount=#valid-included,areaCount=#queue,width=width,height=height,includedKeys={}}
 for _,n in ipairs(includedNodes) do route.includedKeys[nodeKey(n)]=true end
 local message='Local corridor: '..included..' of '..#valid..' selected locations in '..#queue..' farming areas.'
 if route.omittedCount>0 then message=message..' Other areas are outside this circuit.' end
 return route,message
end
