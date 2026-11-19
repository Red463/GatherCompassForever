local _, A = ...
local T={};A.Atlas=T
local S=A.Store
local cacheDB,cacheRevision,cacheIndex
function T.Key(node)
 local info=A.Resources.Info(node)
 return node.kind..':'..(info and tostring(info.id) or tostring(node.materialID))
end
function T.Index(db)
 local revision=S.Number(db.nodeRevision) and db.nodeRevision or 0
 if cacheDB==db and cacheRevision==revision then return cacheIndex end
 local result={resources={},zones={}};local groups={};local seen={}
 for mapID,list in pairs(db.nodes) do if S.Number(mapID) and mapID>0 and type(list)=='table' then
  result.zones[#result.zones+1]=mapID
  for _,node in ipairs(S.Select(db,mapID)) do
   if type(node.key)=='string' and (node.kind=='herb' or node.kind=='ore') and node.mapID==mapID and not seen[mapID..':'..node.key] then
    seen[mapID..':'..node.key]=true
    local id=T.Key(node);local group=groups[id]
    if not group then
     local info=A.Resources.Info(node)
     group={id=id,name=info and info.name or type(node.name)=='string' and node.name or node.materialID,kind=node.kind,sample=node,icon=A.Resources.Icon(node),nodes={}}
     groups[id]=group;result.resources[#result.resources+1]=group
    end
    group.nodes[#group.nodes+1]=node
   end
  end
 end end
 table.sort(result.zones)
 table.sort(result.resources,function(a,b) return a.id<b.id end)
 cacheDB,cacheRevision,cacheIndex=db,revision,result;return result
end
local function matches(node,filter)
 local source=filter.source or 'combined'
 return (source=='combined' or source=='confirmed' and node.confirmed or source=='imported' and node.imported)
  and (not filter.materials or filter.materials[node.materialID])
end
local function stats(group,node)
 group.count=group.count+1
 if node.confirmed then group.confirmed=group.confirmed+1 end
 if node.imported then group.imported=group.imported+1 end
 if node.confirmed and S.Number(node.count) then group.harvests=group.harvests+math.max(0,math.floor(node.count)) end
 if node.confirmed and S.Number(node.lastGathered) and node.lastGathered>group.lastGathered then group.lastGathered=node.lastGathered end
end
local function emptyStats() return {count=0,confirmed=0,imported=0,harvests=0,lastGathered=0} end
local difficultyOrder={orange=1,yellow=2,green=3,grey=4,red=5,unknown=6}
local scopedIndex,scopedSignature,scopedGroups
local function locationOrder(a,b)
 if a.node.mapID~=b.node.mapID then return a.node.mapID<b.node.mapID end
 return a.node.key<b.node.key
end
local function scoped(index,scope,mapID,filter)
 local materials={}
 if filter.materials then for id,on in pairs(filter.materials) do if type(id)=='string' and on then materials[#materials+1]=id end end;table.sort(materials) end
 -- Length-prefixed IDs avoid collisions and detect in-place checkbox edits.
 for i,id in ipairs(materials) do materials[i]=#id..':'..id end
 local signature=(scope=='all' and 'all' or tostring(mapID))..'/'..tostring(filter.source or 'combined')..'/'..tostring(filter.kind or 'both')..'/'..(filter.materials and table.concat(materials) or '*')
 if scopedIndex==index and scopedSignature==signature then return scopedGroups end
 local groups={}
 for _,entry in ipairs(index.resources) do if not filter.kind or filter.kind=='both' or filter.kind==entry.kind then
  local group=emptyStats();group.id=entry.id;group.name=entry.name;group.kind=entry.kind;group.icon=entry.icon
  group.nodes={};group.allNodes={};group.byZone={};group.materialIDs={};group.locations={};local zones={}
  for _,node in ipairs(entry.nodes) do if matches(node,filter) then
   group.allNodes[#group.allNodes+1]=node;group.materialIDs[node.materialID]=true
   local zone=zones[node.mapID]
   if not zone then zone=emptyStats();zone.mapID=node.mapID;zones[node.mapID]=zone end
   stats(zone,node)
   if scope=='all' or mapID and node.mapID==mapID then
    group.nodes[#group.nodes+1]=node;stats(group,node)
    group.byZone[node.mapID]=group.byZone[node.mapID] or {};local list=group.byZone[node.mapID];list[#list+1]=node
    group.locations[#group.locations+1]={node=node}
   end
  end end
  if group.count>0 then
   group.zones={};for _,zone in pairs(zones) do group.zones[#group.zones+1]=zone end
   table.sort(group.zones,function(a,b) if a.count~=b.count then return a.count>b.count end;return a.mapID<b.mapID end)
   table.sort(group.locations,locationOrder);groups[#groups+1]=group
  end
 end end
 scopedIndex,scopedSignature,scopedGroups=index,signature,groups;return groups
end
function T.Query(db,player,filter,options,skills,context,distance)
 filter=filter or {};options=options or {};skills=skills or {}
 local index=T.Index(db);local result={groups={},zoneIDs=index.zones,totalLocations=0}
 local scope=options.zone or 'current';local mapID=scope=='current' and player and player.mapID or S.Number(scope) and scope or nil
 for _,base in ipairs(scoped(index,scope,mapID,filter)) do
  local detail=A.Resources.SkillDetails(base.nodes[1],skills,context);local key=detail.key
  local wanted=not options.skill or options.skill=='all' or options.skill=='gatherable' and key~='red' and key~='unknown' or options.skill=='skillups' and (key=='orange' or key=='yellow' or key=='green')
  if wanted then
   local group={};for k,v in pairs(base) do group[k]=v end
   group.skill=detail;group.currentNodes=player and base.byZone[player.mapID] or {}
   group.currentNodes=group.currentNodes or {}
   if distance and #group.currentNodes>0 then
    local located,distances={},{}
    for _,node in ipairs(group.currentNodes) do
     local d=distance(player,node)
     if S.Number(d) and d>=0 then distances[node.key]=d;located[#located+1]={node=node,distance=d} end
    end
    table.sort(located,function(a,b) if a.distance~=b.distance then return a.distance<b.distance end;return locationOrder(a,b) end)
    if located[1] then group.distance=located[1].distance;group.nearest=located[1].node end
    -- Remote entries retain their cached order and records; only local distances change.
    group.locations=located
    for _,entry in ipairs(base.locations) do if not distances[entry.node.key] then group.locations[#group.locations+1]=entry end end
   end
   result.groups[#result.groups+1]=group;result.totalLocations=result.totalLocations+group.count
  end
 end
 table.sort(result.groups,function(a,b)
  local mode=options.sort or 'nearest';local av,bv
  if mode=='nearest' then av,bv=a.distance or math.huge,b.distance or math.huge
  elseif mode=='difficulty' then av,bv=difficultyOrder[a.skill.key],difficultyOrder[b.skill.key]
  elseif mode=='gathers' then av,bv=-a.harvests,-b.harvests
  elseif mode=='recent' then av,bv=-a.lastGathered,-b.lastGathered end
  if av and av~=bv then return av<bv end
  local an,bn=a.name:lower(),b.name:lower();if an~=bn then return an<bn end;return a.id<b.id
 end)
 return result
end
