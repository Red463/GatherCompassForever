local addonName, A = ...
A.version='0.8.7'
function A.Print(text)
 if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage('|cff65dbc1Gather Compass:|r '..tostring(text)) end
end
function A.Import()
 if A.importJob then A.status='An import is already running.'; A.UI.Refresh(); return end
 local provider,stats=A.Imports.Provider()
 if not provider then A.status='Enable compatible GatherMate2 and GatherMate2_Data addons to import spawn data. Personal recording still works.'; A.UI.Refresh(); return end
 A.importJob=coroutine.create(function()
  local count,processed=0,0; local zones={}
  local ok,err=pcall(function()
   -- The coroutine yields outside pcall below: Lua 5.1 cannot yield across pcall.
   local iter,state,key=provider(); A.importIterator={iter,state,key}
  end)
  if not ok then A.status='Import unavailable: '..tostring(err); return end
  while true do
   local it=A.importIterator; local good,k,o=pcall(it[1],it[2],it[3]); it[3]=k
   if not good then A.status='Import stopped: '..tostring(k); return end
   if k==nil then break end
   processed=processed+1
   if type(o)=='table' then o.source='imported'; if A.Store.Observe(A.db,o) then count=count+1; zones[o.mapID]=true end end
   if processed%40==0 then A.status='Importing all zones: '..count..' locations…'; coroutine.yield() end
  end
  if count==0 then
   if stats and stats.scanned>0 then
    A.status='GatherMate2 supplied '..stats.scanned..' rows, but none were usable. Check that its data supports Forever.'
   elseif stats and stats.loadError then
    A.status='Import could not load GatherMate2_Data ('..stats.loadError..'). Install and enable the Forever data pack and its GatherMate2 dependency, then restart WoW and retry.'
   elseif stats and stats.rawAvailable then
    A.status='The installed data pack contains no usable herb/ore points, and GatherMate2 has no fallback points. Check that you installed the Forever data pack.'
   else
    A.status='Import found no available tables in GatherMate2_Data or GatherMate2. The raw tables may have been cleared; reload the UI and retry before using GatherMate2\'s own import.'
   end
   A.Print(A.status)
  else
   local source=stats and stats.direct>0 and (stats.fallback>0 and 'GatherMate2_Data + GatherMate2' or 'GatherMate2_Data') or 'GatherMate2 database (fallback)'
   local zoneCount=0; for _ in pairs(zones) do zoneCount=zoneCount+1 end
   A.status='Imported '..count..' locations across '..zoneCount..' zones from '..source..'. Personal confirmations unchanged.'
  end
 end)
 A.status='Import queued for all available zones.'; A.UI.Refresh()
end
function A.Initialize()
 if A.initialized then A.MinimapButton.Build();return true end
 if A.uiError then return nil,A.uiError end
 if not A.dataReady then
  A.Store.distance=A.Client.Distance
  A.db,A.writable,A.storageReason=A.Store.Open(GatherCompassForeverDB)
  if A.writable then GatherCompassForeverDB=A.db end
  A.detector=A.Gathering.New(function(o)
   o.time=time and time() or 0
   local n=A.Store.Observe(A.db,o)
   if n then A.status='Confirmed '..(n.name or n.materialID)..'.'; A.UI.Refresh() end
  end)
  A.dataReady=true
 end
 local ok,reason=pcall(function()
  local ready,errorText=A.UI.Build();if not ready then error(errorText,0) end
  A.Arrow.Build()
  A.MinimapButton.Build()
 end)
 if not ok then
  A.uiError=tostring(reason);A.status='Panel unavailable: '..A.uiError
  if A.UI.frame then A.UI.frame:Hide() end
  if A.Arrow.frame then A.Arrow.frame:Hide() end
  A.Print(A.status..' Use /gcf status to see this error again.');return nil,A.uiError
 end
 A.initialized=true
 A.Print('Loaded. /gcf opens routes and gathering controls.')
 return true
end
function A.Command(text)
 if not A.initialized then
  local previousError=A.uiError;local ready,reason=A.Initialize()
  if not ready then if previousError then A.Print('Panel unavailable: '..reason) end;return end
 end
 text=(text or ''):lower():match('^%s*(.-)%s*$')
 if text=='inspect' then A.DifficultyProbe.Arm()
 elseif text=='inspect report' then A.DifficultyProbe.Report()
 elseif text=='inspect off' then A.DifficultyProbe.Cancel()
 elseif text=='import' then A.Import()
 elseif text=='stop' then A.UI.actions.stop()
 elseif text=='skip' then if A.follower then A.follower:Skip() end
 elseif text=='status' then A.Print(A.status or 'Ready.'); A.Print(A.storageReason or 'Persistent storage active.')
 else A.UI.Toggle() end
end
local fast,slow=0,0
function A.Tick(elapsed)
 if not A.initialized then return end
 fast=fast+elapsed; slow=slow+elapsed
 if fast>=.1 then
  fast=0; local p=A.Client.Position(); local now=A.Client.Now()
  if A.importJob then
   local ok,err=coroutine.resume(A.importJob)
   if not ok then A.status='Import stopped safely: '..tostring(err) end
   if not ok or coroutine.status(A.importJob)=='dead' then A.importJob=nil; A.importIterator=nil end
  end
  A.detector:Expire(now)
  if A.recording then A.recording:Sample(p,now) end
  if A.follower then A.follower:Tick(p,now,A.detector:IsGathering(now)) end
  local f=A.follower
  A.Arrow.Update(p,A.Client.Facing(),f and f:Target() or nil,A.Client.Distance,f and f:Snapshot() or nil)
 end
 if slow>=.5 then
  slow=0; A.UI.Refresh(); A.Map.Refresh(A.db,A.UI.DisplayRoute(),A.editor and nil or A.follower)
 end
end
function A.OnEvent(_,event,...)
 if event=='ADDON_LOADED' then local name=...; if name==addonName then A.Initialize() end; return end
 if event=='PLAYER_LOGIN' then A.Initialize(); return end
 if not A.initialized then return end
 if event=='UNIT_SPELLCAST_SENT' then
  local unit,target,guid,id=...
  if A.Client.Read(unit)=='player' then
   local attempt=A.Client.Attempt(target,guid,id)
   if attempt then A.detector:Sent(attempt) else A.detector:Cancel(A.Client.Now()) end
  end
 elseif event=='UNIT_SPELLCAST_SUCCEEDED' or event=='UNIT_SPELLCAST_FAILED' or event=='UNIT_SPELLCAST_INTERRUPTED' then
  local unit,guid=...; unit=A.Client.Read(unit); guid=A.Client.Read(guid)
  if unit=='player' and type(guid)=='string' then
   if event=='UNIT_SPELLCAST_SUCCEEDED' then A.detector:Succeeded(guid,A.Client.Now()) else A.detector:Failed(guid) end
  end
 elseif event=='LOOT_READY' or event=='LOOT_OPENED' then
  local evidence,reason=A.Client.LootEvidence()
  if reason and next(A.detector.pending) then A.detector.reason=reason end
  for _,e in ipairs(evidence) do A.detector:Loot(e,A.Client.Now()) end
 elseif event=='PLAYER_LOGOUT' then
  -- Explicitly stopped recordings are saved only through their Save control.
  -- A crash or disconnect cannot overwrite a route with a partial recording.
  if A.writable then GatherCompassForeverDB=A.db end
 end
end
-- Register before native widgets are built, including on partial UI failure.
if SlashCmdList then SLASH_GATHERCOMPASSFOREVER1='/gcf';SlashCmdList.GATHERCOMPASSFOREVER=A.Command end
if CreateFrame then
 A.frame=CreateFrame('Frame')
 for _,event in ipairs({'ADDON_LOADED','PLAYER_LOGIN','PLAYER_LOGOUT','UNIT_SPELLCAST_SENT','UNIT_SPELLCAST_SUCCEEDED','UNIT_SPELLCAST_FAILED','UNIT_SPELLCAST_INTERRUPTED','LOOT_READY','LOOT_OPENED'}) do A.frame:RegisterEvent(event) end
 A.frame:SetScript('OnEvent',A.OnEvent); A.frame:SetScript('OnUpdate',function(_,elapsed) A.Tick(elapsed) end)
end
