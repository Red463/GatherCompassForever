local _, A = ...
local G={}; A.Gathering=G
function G.New(callback)
 local d={pending={},callback=callback}
 function d:Expire(now)
  for id,a in pairs(self.pending) do
   if now-a.time>10 then
    if a.succeeded then self.ambiguousUntil=math.max(self.ambiguousUntil or 0,now+30) end
    self.pending[id]=nil
   end
  end
 end
 function d:Sent(a)
  if not A.Store.Position(a) or type(a.castGUID)~='string' or (a.kind~='herb' and a.kind~='ore') then return end
  self:Expire(a.time); self.pending[a.castGUID]=A.Store.Copy(a)
 end
 function d:Try(a)
  if not a.succeeded or not a.loot then return end
  if math.abs(a.lootAt-a.succeeded)>1.5 then a.loot=nil; return end
  self.pending[a.castGUID]=nil
  local o=A.Store.Copy(a); o.materialID=a.materialID or ('item:'..a.loot.itemID)
  o.objectID=a.loot.objectID; o.source='confirmed'; o.time=a.succeeded
  self.callback(o)
  self.reason=nil
 end
 function d:Succeeded(id,now)
  self:Expire(now); local a=self.pending[id]; if a then a.succeeded=now; self:Try(a) end
 end
 function d:Failed(id) self.pending[id]=nil end
 function d:Cancel(now)
  for _,a in pairs(self.pending) do if a.succeeded then self.ambiguousUntil=math.max(self.ambiguousUntil or 0,now+30) end end
  self.pending={}
 end
 function d:Loot(e,now)
  self:Expire(now)
  if not next(self.pending) then return end
  if e.ambiguous or type(e.sourceGUID)~='string' or not e.sourceGUID:match('^GameObject%-') or not A.Store.Number(e.itemID) then self.reason='Ambiguous loot source; gather not confirmed.'; return end
  local candidate,count=nil,0
  for _,a in pairs(self.pending) do
   local identity
   if a.sourceGUID then identity=a.sourceGUID==e.sourceGUID
   elseif not self.ambiguousUntil or now>self.ambiguousUntil then
    identity=(a.kind=='herb' and type(e.itemName)=='string' and e.itemName==a.name) or (a.expectedItems and a.expectedItems[e.itemID])
   end
   if identity and now>=a.time and (not a.succeeded or math.abs(now-a.succeeded)<=1.5) and (not e.kind or a.kind==e.kind) then count=count+1; candidate=a end
  end
  if count~=1 then self.reason='Loot identity did not uniquely match the gather; left unconfirmed.'; return end
  candidate.loot=e; candidate.lootAt=now; self:Try(candidate)
 end
 function d:IsGathering(now)
  self:Expire(now)
  for _,a in pairs(self.pending) do if not a.succeeded then return true end end
  return false
 end
 return d
end
