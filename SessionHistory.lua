local _,A=...
local H={};A.SessionHistory=H
local S=A.Store
local function integer(n) return S.Number(n) and n>=0 and n%1==0 and n<2^53 end
local function text(s) return type(s)=='string' and s:sub(1,160) or nil end
local function priceAPI()
 local api=type(Auctionator)=='table' and Auctionator.API
 api=type(api)=='table' and api.v1
 return type(api)=='table' and type(api.GetAuctionPriceByItemID)=='function' and api.GetAuctionPriceByItemID or nil
end
local function valueItems(saved,prices)
 if not prices then return end
 saved.valuation={source='Auctionator',totalCopper=0,pricedKinds=0,unpricedKinds=0}
 for id,item in pairs(saved.items) do
  local price=prices[id]
  item.unitPrice=nil;item.totalCopper=nil
  if integer(price) and integer(price*item.quantity) and integer(saved.valuation.totalCopper+price*item.quantity) then
   item.unitPrice=price;item.totalCopper=price*item.quantity
   saved.valuation.totalCopper=saved.valuation.totalCopper+item.totalCopper;saved.valuation.pricedKinds=saved.valuation.pricedKinds+1
  else saved.valuation.unpricedKinds=saved.valuation.unpricedKinds+1 end
 end
end
function H.New(db,character)
 if type(db)~='table' or type(character)~='table' or not text(character.key) or character.key=='' then return nil end
 if db.sessionHistory==nil then db.sessionHistory={version=1,characters={}} end
 local history=db.sessionHistory
 if type(history)~='table' or history.version~=1 or type(history.characters)~='table' then return nil end
 local data=history.characters[character.key]
 if data==nil then data={nextID=1,sessions={}};history.characters[character.key]=data end
 if type(data)~='table' or type(data.sessions)~='table' then return nil end
 data.nextID=integer(data.nextID) and math.max(1,data.nextID) or 1
 local journal={character=S.Copy(character)};local closed={}
 local function accounting(sessionID,late)
  if data.active and data.active.id==sessionID then return data.active end
  local old=late and closed[sessionID]
  if old then return old.active,old.saved,old.prices end
 end
 function journal:Active() return data.active end
 function journal:Begin(route,now)
  if data.active then return data.active end
  if not integer(now) then return nil end
  route=route or {}
  local id=tostring(data.nextID);data.nextID=data.nextID+1
  data.active={id=id,startedAt=now,routeName=text(route.name) or 'Farming route',mapID=route.mapID,
   characterName=text(character.name),realm=text(character.realm),items={},gathers=0,herbGathers=0,oreGathers=0,
   receipts={},casts={},expectedItems={},windowSequence=0}
  return data.active
 end
 function journal:NewWindow()
  local active=data.active;if not active then return nil end
  active.windowSequence=active.windowSequence+1;return active.windowSequence
 end
 function journal:Expect(sessionID,itemID)
  local active=data.active
  if active and active.id==sessionID and integer(itemID) and itemID>0 then
   active.expectedItems=active.expectedItems or {};active.expectedItems[itemID]=true
  end
 end
 function journal:Gather(o,late)
  local active,saved=accounting(o.sessionID,late)
  if not active or type(o.castGUID)~='string' or (o.kind~='herb' and o.kind~='ore') or active.casts[o.castGUID] then return nil end
  active.casts[o.castGUID]=true;active.gathers=active.gathers+1
  local key=o.kind=='herb' and 'herbGathers' or 'oreGathers';active[key]=active[key]+1
  if saved then saved.gathers=active.gathers;saved.herbGathers=active.herbGathers;saved.oreGathers=active.oreGathers end
  return true
 end
 function journal:Loot(sessionID,receipt,item,late)
  local active,saved,prices=accounting(sessionID,late)
  if not active or type(receipt)~='string' or active.receipts[receipt] or type(item)~='table'
   or not integer(item.itemID) or item.itemID<1 or not integer(item.quantity) or item.quantity<1 then return nil end
  local row=active.items[item.itemID]
  local quantity=(row and row.quantity or 0)+item.quantity
  if not integer(quantity) then return nil end
  if not row then row={itemID=item.itemID,quantity=0};active.items[item.itemID]=row end
  row.name=text(item.itemName) or row.name;row.link=text(item.itemLink) or row.link;row.quantity=quantity
  active.receipts[receipt]=true
  if saved then saved.items[item.itemID]=S.Copy(row);valueItems(saved,prices) end
  return true
 end
 function journal:Stop(now)
  local active=data.active;if not active or not integer(now) then return nil end
  local saved=S.Copy(active);saved.endedAt=now;saved.duration=math.max(0,now-saved.startedAt)
  saved.receipts=nil;saved.casts=nil;saved.windowSequence=nil;saved.expectedItems=nil
  local api=priceAPI();local prices=api and {}
  if api then
   local expected=S.Copy(active.expectedItems or {});for id in pairs(saved.items) do expected[id]=true end
   for id in pairs(expected) do local ok,price=pcall(api,'Gatherly',id);if ok and integer(price) then prices[id]=price end end
  end
  valueItems(saved,prices)
  -- Keep only a brief in-memory accounting tail for loot cleared before Stop
  -- whose cast-success event arrives afterwards. Prices remain those at Stop.
  for id,old in pairs(closed) do if now-old.saved.endedAt>10 then closed[id]=nil end end
  closed[active.id]={active=active,saved=saved,prices=prices}
  data.sessions[#data.sessions+1]=saved;data.active=nil;return saved
 end
 function journal:List()
  local result={};for i=#data.sessions,1,-1 do result[#result+1]=data.sessions[i] end;return result
 end
 return journal
end
