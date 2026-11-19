local _,A=...
local G={};A.MarkerGroups=G
function G.Summary(nodes)
 local entries,byID={},{}
 for _,n in ipairs(nodes) do
  local info=A.Resources.Info(n);local id=n.kind..':'..tostring(info and info.id or n.materialID)
  local e=byID[id]
  if not e then e={key=id,node=n,name=info and info.name or n.name or n.materialID,count=0};byID[id]=e;entries[#entries+1]=e end
  e.count=e.count+1
  if tostring(n.key or '')<tostring(e.node.key or '') then e.node=n end
 end
 table.sort(entries,function(a,b) if a.count~=b.count then return a.count>b.count end;return a.key<b.key end)
 return entries
end
function G.Build(nodes,project,radius,options)
 options=options or {};radius=math.max(1,radius or 14)
 local ordered={}
 for _,n in ipairs(nodes) do local x,y=project(n)
  if A.Store.Number(x) and A.Store.Number(y) then ordered[#ordered+1]={node=n,x=x,y=y,key=tostring(n.key or n.materialID or '')} end
 end
 table.sort(ordered,function(a,b)
  if (a.key==options.focus)~=(b.key==options.focus) then return a.key==options.focus end
  return a.key<b.key
 end)
 local groups,buckets={},{};local comparisons=0
 local function bucket(map,x,y) return tostring(map)..':'..x..':'..y end
 for _,p in ipairs(ordered) do
  local cx,cy=math.floor(p.x/radius),math.floor(p.y/radius);local best,bestDistance
  if not options.disabled then for dx=-1,1 do for dy=-1,1 do for _,g in ipairs(buckets[bucket(p.node.mapID,cx+dx,cy+dy)] or {}) do
   comparisons=comparisons+1;local d=(p.x-g.x)^2+(p.y-g.y)^2
   if d<=radius*radius and (not bestDistance or d<bestDistance) then best,bestDistance=g,d end
  end end end end
  if not best then
   best={anchor=p.node,x=p.x,y=p.y,members={},mixed=false,hash=0};groups[#groups+1]=best
   local key=bucket(p.node.mapID,cx,cy);buckets[key]=buckets[key] or {};buckets[key][#buckets[key]+1]=best
  end
  best.members[#best.members+1]=p.node
  if p.node.materialID~=best.anchor.materialID or p.node.kind~=best.anchor.kind then best.mixed=true end
  local hash=0;for i=1,#p.key do hash=(hash*33+p.key:byte(i))%2147483647 end
  best.hash=(best.hash+hash)%2147483647
 end
 for _,g in ipairs(groups) do
  g.key=tostring(g.anchor.key)..':'..#g.members..':'..g.hash
  g.entries=G.Summary(g.members);g.representative=g.entries[1].node;g.mixed=#g.entries>1
 end
 groups.total=#groups;groups.comparisons=comparisons
 if options.limit then while #groups>options.limit do table.remove(groups) end end
 return groups
end
