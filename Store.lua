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
function S.Observe(db,o)
 if not S.Position(o) or (o.kind~='herb' and o.kind~='ore') or type(o.materialID)~='string' or #o.materialID>100 or (o.source~='confirmed' and o.source~='imported') then return nil end
 local list=db.nodes[o.mapID] or {}; db.nodes[o.mapID]=list
 local match
 for _,n in ipairs(list) do
  local alias=n.name and o.name and n.name==o.name and (n.materialID:match('^node:') or o.materialID:match('^node:'))
  if n.kind==o.kind and (n.materialID==o.materialID or alias) and not (n.objectID and o.objectID and n.objectID~=o.objectID) then
   local d=S.distance and S.distance(n,o)
   if (d and d<=5) or (n.x==o.x and n.y==o.y) then match=n; break end
  end
 end
 if not match then
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
 return match
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
