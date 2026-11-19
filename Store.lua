local _, A = ...
local S = {}; A.Store = S
function S.Number(v)
 return not (issecretvalue and issecretvalue(v)) and type(v)=='number' and v==v and v>-math.huge and v<math.huge
end
function S.Position(p)
 return type(p)=='table' and S.Number(p.mapID) and p.mapID>0 and p.mapID%1==0 and S.Number(p.x) and S.Number(p.y) and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1
end
function S.Copy(v)
 if type(v)~='table' then return v end
 local r={}; for k,x in pairs(v) do r[k]=S.Copy(x) end; return r
end
-- Expand canonical aliases once per selection, not once per observed node.
-- Exact entries (including exclusions) take precedence over inherited aliases.
function S.ExpandedMaterials(materials,aliases)
 if type(materials)~='table' then return nil end
 if type(aliases)~='table' or not next(aliases) then return materials end
 local function canonical(id)
  for _=1,16 do local target=aliases[id];if type(target)~='string' or target=='' or target==id then break end;id=target end
  return id
 end
 local result={};for id,on in pairs(materials) do result[id]=on end
 for id,on in pairs(materials) do if on then local target=canonical(id);if result[target]==nil then result[target]=true end end end
 for id in pairs(aliases) do if result[id]==nil then result[id]=result[canonical(id)] end end
 return result
end
local function fresh() return {version=1,nodes={},routes={},nextNode=1,nextRoute=1,settings={source='combined',kind='both',arrival=15,arrowScale=1}} end
function S.Open(saved)
 if saved==nil then return fresh(),true end
 if type(saved)~='table' or saved.version~=1 or type(saved.nodes)~='table' or type(saved.routes)~='table' then
  return fresh(),false,'Unrecognised saved schema; using temporary memory. Your saved data is preserved.'
 end
 saved.settings=type(saved.settings)=='table' and saved.settings or fresh().settings
 saved.nextNode=tonumber(saved.nextNode) or 1; saved.nextRoute=tonumber(saved.nextRoute) or 1
 return saved,true
end
function S.Observe(db,o,candidates)
 if not S.Position(o) or (o.kind~='herb' and o.kind~='ore') or type(o.materialID)~='string' or #o.materialID>100 or (o.source~='confirmed' and o.source~='imported') then return nil end
 local list=db.nodes[o.mapID] or {}; db.nodes[o.mapID]=list
 local match;local created=false
 for _,n in ipairs(candidates or list) do
  local alias=n.name and o.name and n.name==o.name and (n.materialID:match('^node:') or o.materialID:match('^node:'))
  if n.kind==o.kind and (n.materialID==o.materialID or alias) and not (n.objectID and o.objectID and n.objectID~=o.objectID) then
   local exact=n.x==o.x and n.y==o.y
   local d=not exact and S.distance and S.distance(n,o)
   if exact or (d and d<=5) then match=n; break end
  end
 end
 if not match then
  created=true
  match={mapID=o.mapID,x=o.x,y=o.y,kind=o.kind,materialID=o.materialID,name=o.name or o.materialID,key='n'..db.nextNode,count=0}
  db.nextNode=db.nextNode+1; list[#list+1]=match
 end
 match.objectID=match.objectID or o.objectID
 if match.materialID~=o.materialID and o.materialID:match('^gm:') then
  local old=match.materialID; match.materialID=o.materialID
  local settings=db.settings
  settings.materialAliases=type(settings.materialAliases)=='table' and settings.materialAliases or {};settings.materialAliases[old]=o.materialID
  for _,profile in ipairs({settings,type(settings.markerFilters)=='table' and settings.markerFilters or {}}) do
   local choices=profile.materials
   if type(choices)=='table' and choices[old]~=nil and choices[o.materialID]==nil then choices[o.materialID]=choices[old] end
  end
 end
 if o.name then match.name=o.name end
 if o.source=='imported' then match.imported=true else
  match.confirmed=true; match.count=(match.count or 0)+1; match.lastGathered=o.time
  -- Prefer coordinates from an actual interaction over imported coordinates.
  match.x,match.y=o.x,o.y
 end
 db.nodeRevision=(S.Number(db.nodeRevision) and db.nodeRevision or 0)+1
 return match,created
end
-- An import owns this disposable grid. Ordinary gathers keep the same merge
-- policy; their revision changes invalidate any grid built before they moved.
function S.ImportWriter(db,size,checkpoint)
 local caches,revision={},db.nodeRevision
 local function stamp() return type(GetTime)=='function' and GetTime() or nil end
 local function insert(cache,n,i)
  if not S.Position(n) then return end
  local x,y=math.floor(n.x*cache.width/5),math.floor(n.y*cache.height/5)
  local column=cache.cells[x] or {};cache.cells[x]=column
  local cell=column[y] or {};column[y]=cell;cell[#cell+1]=n;cache.order[n]=i
 end
 local function build(mapID)
  local w,h;if size then w,h=size(mapID) end
  if not S.Number(w) or not S.Number(h) or w<=0 or h<=0 then return {fallback=true,width=w,height=h,stamp=stamp()} end
  local before,frame=db.nodeRevision,stamp();local cache={width=w,height=h,cells={},order={}}
  for i,n in ipairs(db.nodes[mapID] or {}) do insert(cache,n,i);if checkpoint then checkpoint() end end
  if before~=db.nodeRevision then return nil end
  if stamp()~=frame and size then local nowW,nowH=size(mapID);if nowW~=w or nowH~=h then return nil end end
  cache.stamp=stamp()
  return cache
 end
 return function(o)
  if not S.Position(o) then return nil end
  if revision~=db.nodeRevision then caches={} end
  local cache=caches[o.mapID]
  local frame=stamp()
  if cache and cache.stamp~=frame then
   local w,h;if size then w,h=size(o.mapID) end
   if cache.width~=w or cache.height~=h then cache=nil else cache.stamp=frame end
  end
  while not cache do cache=build(o.mapID);if not cache then caches={} end end
  caches[o.mapID]=cache
  local candidates
  if not cache.fallback then
   candidates={};local x,y=math.floor(o.x*cache.width/5),math.floor(o.y*cache.height/5)
   for dx=-1,1 do local column=cache.cells[x+dx]
    if column then for dy=-1,1 do
     for _,n in ipairs(column[y+dy] or {}) do candidates[#candidates+1]=n end
    end end
   end
   table.sort(candidates,function(a,b) return cache.order[a]<cache.order[b] end)
  end
  local n,created=S.Observe(db,o,candidates)
  if created and not cache.fallback then insert(cache,n,#db.nodes[o.mapID]) end
  revision=db.nodeRevision;return n,created
 end
end
function S.Select(db,mapID,filter)
 local result={}; filter=filter or {}; local source=filter.source or 'combined'
 local materials=S.ExpandedMaterials(filter.materials,db.settings and db.settings.materialAliases or filter.aliases)
 for _,n in ipairs(db.nodes[mapID] or {}) do
  local provenance=(source=='confirmed' and n.confirmed) or (source=='imported' and n.imported) or (source=='combined' and (n.confirmed or n.imported))
  if S.Position(n) and provenance and (not filter.kind or filter.kind=='both' or filter.kind==n.kind) and (not materials or materials[n.materialID]) then result[#result+1]=n end
 end
 return result
end
function S.SaveRoute(db,r)
 if type(r)~='table' or type(r.name)~='string' or not r.name:find('%S') or #r.name>80 or not S.Number(r.mapID) or type(r.points)~='table' or #r.points==0 or #r.points>2000 then return nil,'Name and 1–2000 valid same-zone points required.' end
 for _,p in ipairs(r.points) do if not S.Position(p) or p.mapID~=r.mapID then return nil,'Route points must be in the same zone.' end end
 local id=r.id
 if not id or not db.routes[id] then id='r'..db.nextRoute; db.nextRoute=db.nextRoute+1 end
 local copy=S.Copy(r); copy.id=id; db.routes[id]=copy
 return id
end
function S.DeleteRoute(db,id)
 if type(id)~='string' or not db.routes[id] then return nil,'Saved route not found.' end
 db.routes[id]=nil;return true
end
