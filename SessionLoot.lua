local _,A=...
local L={};A.SessionLoot=L
function L.New(journal)
 local tracker={windows={}}
 local function prune(self,now)
  for i=#self.windows,1,-1 do if self.windows[i]~=self.current and now-self.windows[i].at>10 then table.remove(self.windows,i) end end
 end
 local function flush(window)
  if not window.cast then return end
  for slot,item in pairs(window.slots) do if window.cleared[slot] then
   journal:Loot(window.sessionID,window.id..':'..slot,item)
  end end
 end
 function tracker:Snapshot(evidence,now)
  prune(self,now);local active=journal:Active();if not active then return end
  local first=evidence and evidence[1]
  if not first or type(first.sourceGUID)~='string' or not first.sourceGUID:match('^GameObject%-') then return end
  for _,item in ipairs(evidence) do if item.sourceGUID~=first.sourceGUID then return end end
  local w=self.current
  if not w or w.sourceGUID~=first.sourceGUID or w.sessionID~=active.id then
   w={id=tostring(journal:NewWindow()),sessionID=active.id,sourceGUID=first.sourceGUID,at=now,slots={},cleared={}}
   self.current=w;self.windows[#self.windows+1]=w
  end
  for _,item in ipairs(evidence) do
   if A.Store.Number(item.slot) and item.slot>=1 and item.slot%1==0 and not w.slots[item.slot] then w.slots[item.slot]=A.Store.Copy(item) end
  end
 end
 function tracker:Gather(o)
  if o.source~='confirmed' or type(o.sourceGUID)~='string' or not o.sourceGUID:match('^GameObject%-') or not A.Store.Number(o.confirmedAt) then return end
  local active=journal:Active();if not active or o.sessionID~=active.id then return end
  journal:Gather(o)
  -- Select one window for this cast. Repeated taps can share an object GUID,
  -- but their separate loot windows must not be rebound to the next cast.
  for i=#self.windows,1,-1 do
   local w=self.windows[i]
   if w.sessionID==o.sessionID and w.sourceGUID==o.sourceGUID and (not w.cast or w.cast==o.castGUID) and math.abs(w.at-o.confirmedAt)<=1.5 then
    w.cast=o.castGUID;flush(w);return
   end
  end
 end
 function tracker:Cleared(slot,now)
  prune(self,now);local w=self.current
  if not w or not w.slots[slot] then return end
  w.cleared[slot]=true;flush(w)
 end
 function tracker:Closed(now) prune(self,now);self.current=nil end
 return tracker
end
