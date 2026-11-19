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
   item.sources={};item.zones={};item.materialIDs={};item.zoneMap={};items[#items+1]=item;byKey[itemKey]=item
  end
  local row=stats();row.node=sourceNode;row.item=item;item.sources[#item.sources+1]=row;bySource[key]=row
  return row
 end
 for _,node in ipairs(A.Resources.Catalog()) do source(node,node.kind..':'..node.id) end
 for _,group in ipairs(index.resources) do
  local key=A.Atlas.Key(group.sample);local row=bySource[key] or source(S.Copy(group.sample),key);local item=row.item
  for _,node in ipairs(group.nodes) do
   add(item,node);add(row,node);item.materialIDs[node.materialID]=true
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
function L.Query(db,kind,search)
 search=type(search)=='string' and search:lower():match('^%s*(.-)%s*$') or ''
 local result={items={}}
 for _,base in ipairs(L.Index(db)) do if not kind or kind=='all' or kind==base.kind then
  local name=A.Resources.ItemName(base.template)
  if search=='' or name:lower():find(search,1,true) then
   local item={};for key,value in pairs(base) do item[key]=value end
   item.name=name;item.icon=A.Resources.ItemIcon(base.template);result.items[#result.items+1]=item
  end
 end end
 table.sort(result.items,function(a,b) local an,bn=a.name:lower(),b.name:lower();if an~=bn then return an<bn end;return a.id<b.id end)
 return result
end
