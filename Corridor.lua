local _,A=...
local C={};A.Corridor=C
local S=A.Store
local function nodeKey(n) return type(n.key)=='string' and n.key or string.format('%.17g:%.17g:%s',n.x,n.y,tostring(n.materialID)) end
function C.Generate(nodes,start,distance,options)
 options=options or {}
 if not S.Position(start) then return nil,'A readable player position is required.' end
 if #nodes>20000 then return nil,'Too many candidates in this zone. Narrow the material filters.' end
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
 local i=2
 while i<=#trace do
  local p=trace[i];local previous=trace[i-1];local following=trace[i%#trace+1]
  if p.travel and edges[previous.index][following.index] then table.remove(trace,i) else i=i+1 end
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
