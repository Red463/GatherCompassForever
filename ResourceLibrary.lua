local _,A=...
local L={};A.ResourceLibrary=L
local S=A.Store
local cachedIndex,cachedItems
local function stats() return {count=0,confirmed=0,imported=0,harvests=0,lastGathered=0} end
local function add(target,node)
 target.count=target.count+1
 if node.imported then target.imported=target.imported+1 end
 if node.confirmed then
  target.confirmed=target.confirmed+1
  if S.Number(node.count) then target.harvests=target.harvests+math.max(0,math.floor(node.count)) end
  if S.Number(node.lastGathered) then target.lastGathered=math.max(target.lastGathered,node.lastGathered) end
 end
end
function L.Index(db)
 local index=A.Atlas.Index(db);if index==cachedIndex then return cachedItems end
 local items,byKey,bySource={},{},{}
 local function source(sourceNode,key)
  if bySource[key] then return bySource[key] end
  local itemKey=sourceNode.kind..(sourceNode.item and ':item:'..sourceNode.item or ':node:'..key)
  local item=byKey[itemKey]
  if not item then
   item=stats();item.id=itemKey;item.kind=sourceNode.kind;item.itemID=sourceNode.item;item.template=sourceNode
   item.sources={};item.nodes={};item.zones={};item.materialIDs={};item.zoneMap={};items[#items+1]=item;byKey[itemKey]=item
  end
  local row=stats();row.node=sourceNode;row.item=item;item.sources[#item.sources+1]=row;bySource[key]=row
  return row
 end
 for _,node in ipairs(A.Resources.Catalog()) do source(node,node.kind..':'..node.id) end
 for _,group in ipairs(index.resources) do
  local key=A.Atlas.Key(group.sample);local row=bySource[key] or source(S.Copy(group.sample),key);local item=row.item
  for _,node in ipairs(group.nodes) do
   item.nodes[#item.nodes+1]=node;add(item,node);add(row,node);item.materialIDs[node.materialID]=true
   local zone=item.zoneMap[node.mapID]
   if not zone then zone=stats();zone.mapID=node.mapID;item.zoneMap[node.mapID]=zone;item.zones[#item.zones+1]=zone end
   add(zone,node)
  end
 end
 for _,item in ipairs(items) do
  item.zoneMap=nil
  table.sort(item.zones,function(a,b) if a.count~=b.count then return a.count>b.count end;return a.mapID<b.mapID end)
  table.sort(item.sources,function(a,b)
   local ar,br=a.node.required or math.huge,b.node.required or math.huge
   if ar~=br then return ar<br end;return a.node.name<b.node.name
  end)
  for _,row in ipairs(item.sources) do row.item=nil end
 end
 cachedIndex,cachedItems=index,items;return items
end
local skillOrder={orange=1,yellow=2,green=3,grey=4,unknown=5,red=6}
function L.Query(db,kind,search,options)
 options=options or {};search=type(search)=='string' and search:lower():match('^%s*(.-)%s*$') or ''
 local ranks,context=options.ranks,options.context
 if not ranks then ranks,context=A.Resources.Skills() end
 local result={items={}}
 for _,base in ipairs(L.Index(db)) do if not kind or kind=='all' or kind==base.kind then
  local name=A.Resources.ItemName(base.template)
  if search=='' or name:lower():find(search,1,true) then
   local item=stats();item.id=base.id;item.kind=base.kind;item.itemID=base.itemID;item.template=base.template
   item.name=name;item.icon=A.Resources.ItemIcon(base.template);item.sources=base.sources;item.nodes={};item.zones={};item.materialIDs={};local zones={}
   for _,row in ipairs(item.sources) do local d=A.Resources.SkillDetails(row.node,ranks,context)
    if not item.skill or skillOrder[d.key]<skillOrder[item.skill.key] then item.skill=d end
   end
   for _,node in ipairs(base.nodes) do
    local source=options.source or 'combined';local on=source=='combined' or source=='confirmed' and node.confirmed or source=='imported' and node.imported
    if on and (options.scope~='current' or node.mapID==options.mapID) then
     add(item,node);item.nodes[#item.nodes+1]=node;item.materialIDs[node.materialID]=true
     local zone=zones[node.mapID];if not zone then zone=stats();zone.mapID=node.mapID;zones[node.mapID]=zone;item.zones[#item.zones+1]=zone end;add(zone,node)
    end
   end
   table.sort(item.zones,function(a,b) if a.count~=b.count then return a.count>b.count end;return a.mapID<b.mapID end)
   if options.scope~='current' and (not options.source or options.source=='combined') then item.zones=base.zones;item.nodes=base.nodes;item.materialIDs=base.materialIDs end
   local skill=options.skill or 'all';local key=item.skill and item.skill.key or 'unknown'
   local eligible=skill=='all' or skill=='gatherable' and key~='red' and key~='unknown' or skill=='skillups' and (key=='orange' or key=='yellow' or key=='green')
   local located=options.scope~='current' and (not options.source or options.source=='combined') or item.count>0
   if eligible and located then result.items[#result.items+1]=item end
  end
 end end
 table.sort(result.items,function(a,b) local an,bn=a.name:lower(),b.name:lower();if an~=bn then return an<bn end;return a.id<b.id end)
 return result
end
function L.LocalCandidates(db,item,player,filter)
 if not item or not S.Position(player) then return {} end
 local keys={};for _,row in ipairs(item.sources) do keys[A.Atlas.Key(row.node)]=true end
 local result={};for _,n in ipairs(S.Select(db,player.mapID,filter)) do if keys[A.Atlas.Key(n)] then result[#result+1]=n end end
 return result
end
