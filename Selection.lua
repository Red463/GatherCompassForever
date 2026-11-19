local _, A = ...
local M={};A.Selection=M
local cacheDB,cacheRevision,cache
function M.Filter(settings)
 settings=settings or {}
 local source=settings.source;local kind=settings.kind
 if source~='combined' and source~='confirmed' and source~='imported' and source~='none' then source='combined' end
 if kind~='both' and kind~='herb' and kind~='ore' and kind~='none' then kind='both' end
 return {source=source,kind=kind,materials=type(settings.materials)=='table' and settings.materials or nil}
end
function M.Snapshot(filter) return A.Store.Copy(M.Filter(filter)) end
function M.Init(settings)
 if type(settings.markerFilters)~='table' then settings.markerFilters=M.Snapshot(settings) end
 if type(settings.routeMarkerOverride)~='boolean' then settings.routeMarkerOverride=false end
 return settings.markerFilters
end
function M.MarkerSettings(settings) return M.Init(settings) end
function M.EffectiveMarker(settings,follower)
 local base=M.Init(settings)
 if settings.routeMarkerOverride and follower and (follower.status=='running' or follower.status=='paused' or follower.status=='suspended') and follower.markerFilter then return M.Filter(follower.markerFilter),true end
 return M.Filter(base),false
end
local function toggle(value,key,first,second,both)
 local a=value==both or value==first;local b=value==both or value==second
 if key==first then a=not a elseif key==second then b=not b else return value end
 return a and b and both or a and first or b and second or 'none'
end
function M.ToggleSource(settings,key) settings.source=toggle(M.Filter(settings).source,key,'confirmed','imported','combined') end
function M.ToggleKind(settings,key) settings.kind=toggle(M.Filter(settings).kind,key,'herb','ore','both') end
function M.Matches(node,filter)
 local source=filter.source or 'combined'
 return (source=='combined' and (node.confirmed or node.imported) or source=='confirmed' and node.confirmed or source=='imported' and node.imported)
  and (not filter.kind or filter.kind=='both' or filter.kind==node.kind)
  and (not filter.materials or filter.materials[node.materialID])
end
function M.Materials(db,mapID,settings)
 local f=M.Filter(settings or db.settings)
 local revision=db.nodeRevision or 0
 if cacheDB~=db or cacheRevision~=revision then cacheDB,cacheRevision,cache=db,revision,{} end
 local signature=tostring(mapID or '*')..'/'..f.source..'/'..f.kind
 if cache[signature] then return cache[signature] end
 local entries,seen={},{}
 local function collect(id)
  for _,node in ipairs(A.Store.Select(db,id,{source=f.source,kind=f.kind})) do
   if not seen[node.materialID] then
    local info=A.Resources.Info(node)
    local entry={id=node.materialID,name=info and info.name or type(node.name)=='string' and node.name or node.materialID,kind=node.kind,sample=node}
    seen[entry.id]=true;entries[#entries+1]=entry
   end
  end
 end
 if mapID then collect(mapID) else for id in pairs(db.nodes) do if A.Store.Number(id) then collect(id) end end end
 table.sort(entries,function(a,b) if a.name==b.name then return a.id<b.id end;return a.name<b.name end)
 cache[signature]=entries;return entries
end
function M.ToggleMaterial(db,id,settings)
 if type(id)~='string' then return end
 local s=settings or db.settings
 if not s.materials then
  s.materials={}
  for _,entry in ipairs(M.Materials(db,nil,{source='combined',kind='both'})) do s.materials[entry.id]=true end
 end
 s.materials[id]=not s.materials[id]
end
local function eligible(entry,skills,context,mode)
 local _,_,key=A.Resources.Difficulty(entry.sample,skills,context)
 return key=='orange' or key=='yellow' or key=='green' or mode=='gatherable' and key=='grey'
end
function M.Bulk(db,mode,on,skills,context,settings)
 settings=settings or db.settings
 if mode~='all' and mode~='skillups' and mode~='gatherable' then return end
 if mode=='all' and on then settings.materials=nil;return end
 local selected={}
 if on then for _,entry in ipairs(M.Materials(db,nil,settings)) do if eligible(entry,skills,context,mode) then selected[entry.id]=true end end end
 settings.materials=selected
end
function M.BulkState(db,skills,context,settings)
 settings=settings or db.settings
 local entries=M.Materials(db,nil,settings);local selected=settings.materials
 local result={total=#entries,selected=0,eligible=0,gatherableCount=0,all=selected==nil,skillups=false,gatherable=false};local exact=true;local gatherExact=true
 for _,entry in ipairs(entries) do
  local on=selected==nil or not not selected[entry.id];local can=eligible(entry,skills,context)
  if on then result.selected=result.selected+1 end
  if can then result.eligible=result.eligible+1 end
  if on~=can then exact=false end
  local gather=eligible(entry,skills,context,'gatherable')
  if gather then result.gatherableCount=result.gatherableCount+1 end
  if on~=gather then gatherExact=false end
 end
 result.all=result.all or #entries>0 and result.selected==#entries
 result.skillups=result.eligible>0 and exact
 result.gatherable=result.gatherableCount>0 and gatherExact
 return result
end
