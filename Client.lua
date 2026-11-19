local _, A = ...
local C={}; A.Client=C
local S=A.Store
function C.Read(v) if issecretvalue and issecretvalue(v) then return nil end; return v end
function C.Now() return GetTime and GetTime() or 0 end
function C.HBD() return LibStub and LibStub('HereBeDragons-2.0',true) end
function C.Position()
 if not C_Map or not C_Map.GetBestMapForUnit or not C_Map.GetPlayerMapPosition then return nil end
 local ok,p=pcall(function()
  local map=C.Read(C_Map.GetBestMapForUnit('player')); if not S.Number(map) then return end
  local pos=C_Map.GetPlayerMapPosition(map,'player'); if not pos then return end
  local x,y=pos:GetXY(); local r={mapID=map,x=C.Read(x),y=C.Read(y)}
  if S.Position(r) then return r end
 end)
 if ok then return p end
end
function C.Size(mapID)
 if C_Map and C_Map.GetMapWorldSize then
  local ok,w,h=pcall(C_Map.GetMapWorldSize,mapID)
  if ok and S.Number(w) and S.Number(h) and w>0 and h>0 then return w,h end
 end
 local hbd=C.HBD()
 if hbd and hbd.GetZoneSize then local ok,w,h=pcall(hbd.GetZoneSize,hbd,mapID); if ok and S.Number(w) and S.Number(h) and w>0 and h>0 then return w,h end end
end
function C.Distance(a,b)
 if not S.Position(a) or not S.Position(b) or a.mapID~=b.mapID then return nil end
 local w,h=C.Size(a.mapID); if not w then return nil end
 return math.sqrt(((b.x-a.x)*w)^2+((b.y-a.y)*h)^2)
end
function C.Facing()
 if not GetPlayerFacing then return nil end
 local ok,v=pcall(GetPlayerFacing); if ok and S.Number(v) then return v end
end
function C.MinimapRadius()
 if C_Minimap and type(C_Minimap.GetViewRadius)=='function' then
  local ok,r=pcall(C_Minimap.GetViewRadius);if ok and S.Number(r) and r>0 then return r end
 end
end
function C.MinimapRotationIgnored()
 if not C_Minimap or type(C_Minimap.IsRotateMinimapIgnored)~='function' then return false end
 local ok,value=pcall(C_Minimap.IsRotateMinimapIgnored);if ok then value=C.Read(value);if type(value)=='boolean' then return value end end
end
function C.MinimapShape()
 if type(GetMinimapShape)~='function' then return 'ROUND' end
 local ok,value=pcall(GetMinimapShape);value=ok and C.Read(value)
 return type(value)=='string' and value or 'UNKNOWN'
end
function C.MinimapFacing()
 local ok,rotating=pcall(function() return GetCVar and C.Read(GetCVar('rotateMinimap'))=='1' end)
 if not ok then return nil end;if not rotating then return 0 end
 local ignored=C.MinimapRotationIgnored();if ignored==nil then return nil end;if ignored then return 0 end
 return C.Facing()
end
function C.Probe()
 local p=C.Position(); local w=p and C.Size(p.mapID)
 local radius
 if C_Minimap and C_Minimap.GetViewRadius then local ok,v=pcall(C_Minimap.GetViewRadius); if ok and S.Number(v) and v>0 then radius=v end end
 return {position=p~=nil,distance=w~=nil,loot=type(GetLootSourceInfo)=='function' and type(GetLootSlotLink)=='function',facing=C.Facing()~=nil,minimap=radius~=nil}
end
local spells={ [2366]='herb',[2368]='herb',[3570]='herb',[11993]='herb',[2575]='ore',[2576]='ore',[3564]='ore',[10248]='ore' }
function C.GatherKind(id)
 id=C.Read(id); if not S.Number(id) then return nil end
 if spells[id] then return spells[id] end
 if C_Spell and C_Spell.GetSpellName then
  local name=C.Read(C_Spell.GetSpellName(id)); if type(name)~='string' then return end
  for spell,kind in pairs(spells) do if name==C.Read(C_Spell.GetSpellName(spell)) then return kind end end
 end
end
function C.Material(kind,name)
 -- Stable GatherMate IDs when available; localised target name otherwise.
 local gm=GatherMate2; local db=kind=='herb' and 'Herb Gathering' or 'Mining'
 if gm and gm.GetIDForNode then
  local ok,id=pcall(gm.GetIDForNode,gm,db,name)
  if ok and S.Number(id) then return 'gm:'..kind..':'..id end
 end
 return 'node:'..kind..':'..name
end
function C.Attempt(target,guid,spell)
 target=C.Read(target); guid=C.Read(guid)
 local kind=C.GatherKind(spell); local p=C.Position()
 if not kind or not p or type(guid)~='string' or type(target)~='string' or target=='' then return nil end
 p.castGUID=guid; p.kind=kind; p.name=target; p.materialID=C.Material(kind,target); p.time=C.Now()
 -- Bind to the actual object whenever the client exposes it. A unit with a
 -- different name or a creature GUID is never a substitute for the cast target.
 if UnitGUID and UnitName then
  for _,unit in ipairs({'softinteract','mouseover','target'}) do
   local ok,objectGUID=pcall(UnitGUID,unit); local good,name=pcall(UnitName,unit)
   objectGUID=ok and C.Read(objectGUID); name=good and C.Read(name)
   if type(objectGUID)=='string' and objectGUID:match('^GameObject%-') and name==target then p.sourceGUID=objectGUID; break end
  end
 end
 if kind=='ore' then
  -- Item identities only, no spawn coordinates or external dataset. This
  -- conservative fallback supports English Classic veins without a readable GUID.
  local ores={['Copper Vein']=2770,['Poor Copper Vein']=2770,['Tin Vein']=2771,['Silver Vein']=2775,['Iron Deposit']=2772,['Gold Vein']=2776,['Mithril Deposit']=3858,['Truesilver Deposit']=7911,['Small Thorium Vein']=10620,['Rich Thorium Vein']=10620,['Dark Iron Deposit']=11370}
  local item=ores[target] or ores[target:gsub('^Ooze Covered ','')]
  if item then p.expectedItems={[item]=true} end
 end
 return p
end
function C.LootEvidence()
 local result={}; local sourcesSeen={}; local ambiguous=false
 if not GetNumLootItems or not GetLootSourceInfo or not GetLootSlotLink then return result end
 local ok,count=pcall(GetNumLootItems); if not ok or not S.Number(count) then return result end
 for slot=1,math.min(count,30) do
  local sources={pcall(GetLootSourceInfo,slot)}; local link=C.Read(GetLootSlotLink(slot))
  if sources[1] and type(link)=='string' then
   local itemID=tonumber(link:match('item:(%d+)'))
   for i=2,#sources,2 do
    local guid=C.Read(sources[i])
    if type(guid)=='string' and guid:match('^GameObject%-') and itemID then
     local objectID=tonumber(guid:match('^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-'))
     local itemName=link:match('%[(.-)%]')
     if not itemName and C_Item and C_Item.GetItemNameByID then local good,name=pcall(C_Item.GetItemNameByID,itemID); if good then itemName=C.Read(name) end end
     result[#result+1]={sourceGUID=guid,objectID=objectID,itemID=itemID,itemName=itemName}
     sourcesSeen[guid]=true
    else ambiguous=true end
   end
  end
 end
 local unique=0; for _ in pairs(sourcesSeen) do unique=unique+1 end
 if ambiguous or unique~=1 then return {},'Loot source is ambiguous or unavailable; gather left unconfirmed.' end
 return result
end
