local _, A = ...
A.UIActions={}
function A.UIActions.Bind(U)
 local actions={}
 local function say(s) A.status=s; if A.Print then A.Print(s) end; U.Refresh() end
 local function busy() return A.editor or A.recording or A.recordedDraft end
 local function guard() if busy() then say('Save or discard the current draft or recording first.'); return true end end
 local function position() local p=A.Client.Position(); if not p then say('Player position is unavailable.'); end; return p end
 function actions.close() U.frame:Hide() end
 function actions.minimize() U.SetCompact(true) end
 function actions.expand() U.SetCompact(false) end
 function actions.workReturn() U.SetCompact(false); U.SetTab('routes') end
 function actions.new()
  if guard() then return end
  local p=position(); if not p then return end
  if A.follower then A.follower:Stop(); A.follower=nil end
  U.Edit({name='My '..U.ZoneName(p.mapID)..' trail',mapID=p.mapID,points={},loop=true})
  actions.map(true)
 end
 function actions.generate()
  if guard() then return end
  local player=A.Client.Position()
  local r,reason=A.Planner.Generate(U.SelectedNodes(),player,A.Client.Distance,{zoneName=U.ZoneName(player and player.mapID),routes=A.db.routes})
  if not r then say(reason); return end
  A.follower=nil; U.Edit(r)
  say((reason and reason..' ' or '')..'Direct connections: add detours for bridges, passes and caves before saving.')
 end
 function actions.edit()
  if guard() then return end
  local r=A.selectedRoute and A.db.routes[A.selectedRoute]
  if not r then say('Select a saved route first.'); return end
  A.follower=nil; U.Edit(r);actions.map()
 end
 function actions.confirmDeleteRoute(data)
  if guard() then return end
  if type(data)~='table' or type(data.id)~='string' or A.db.routes[data.id]~=data.route then say('The saved route changed. Select it again to delete it.');return end
  local ok,reason=A.Store.DeleteRoute(A.db,data.id);if not ok then say(reason);return end
  if A.selectedRoute==data.id then A.selectedRoute=nil end
  if A.mapPreviewRoute and (A.mapPreviewRoute==data.route or A.mapPreviewRoute.id==data.id) then A.mapPreviewRoute=nil end
  local following=A.follower and A.follower.route and A.follower.route.id==data.id
  if following then actions.stop() end
  U.Refresh()
  if not following and A.Map then A.Map.Refresh(A.db,U.DisplayRoute(),A.follower) end
  say('Deleted saved route: '..data.route.name..'. Known node locations are unchanged.')
 end
 local deleteDialog='GATHERCOMPASSFOREVER_DELETE_ROUTE'
 if StaticPopupDialogs then
  StaticPopupDialogs[deleteDialog]={
   text='Delete saved route "%s"?\n\nThis cannot be undone. Guidance for this route will stop. Known node locations are kept.',
   button1='Delete route',button2='Cancel',timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
   OnAccept=function(_,data) actions.confirmDeleteRoute(data) end,
  }
 end
 function actions.deleteRoute()
  if guard() then return end
  local id=A.selectedRoute;local route=id and A.db.routes[id]
  if not route then say('Select a saved route first.');return end
  if not StaticPopupDialogs or not StaticPopupDialogs[deleteDialog] or type(StaticPopup_Show)~='function' then say('Delete confirmation is unavailable. The saved route is unchanged.');return end
  StaticPopup_Show(deleteDialog,route.name:gsub('|','||'),nil,{id=id,route=route})
 end
 function actions.save()
  if not A.editor then return end
  local r=A.editor:Route(); r.name=U.name:GetText()
  local id,reason=A.Store.SaveRoute(A.db,r)
  if not id then say(reason); return end
  A.selectedRoute=id; A.editor=nil; if A.Map then A.Map.SetEditor(nil) end; say('Route saved. Ready when you are.')
 end
 function actions.discard()
  A.editor=nil; if A.Map then A.Map.SetEditor(nil) end; U.Refresh()
 end
 function actions.record()
  if A.recording then
   local r,reason=A.recording:Finish(U.name:GetText()); A.recording=nil; A.recordedDraft=r
   say(r and 'Recording finished. Save or discard your trail.' or reason); return
  end
  if guard() then return end
  local p=position(); if not p then return end
  A.follower=nil; A.recording=A.Recorder.New(p.mapID); A.recording:Sample(p,A.Client.Now())
  U.name:SetText('My '..U.ZoneName(p.mapID)..' recording'); U.SetTab('routes'); say('Recording your travelled path.')
 end
 function actions.resumeRecording()
  if A.recording and not A.recording:Resume(A.Client.Position()) then say('Return within 5 yards of the last recorded point to resume.') else U.Refresh() end
 end
 function actions.saveRecording()
  if not A.recordedDraft then return end
  local copy=A.Store.Copy(A.recordedDraft); copy.name=U.name:GetText()
  local id,reason=A.Store.SaveRoute(A.db,copy)
  if id then A.selectedRoute=id; A.recordedDraft=nil; say('Recorded path saved.') else say(reason) end
 end
 function actions.discardRecording() A.recordedDraft=nil; U.Refresh() end
 function actions.pointPrev() A.editIndex=math.max(1,(A.editIndex or 1)-1); U.Refresh() end
 function actions.pointNext()
  local r=A.editor and A.editor.draft or A.recordedDraft or A.recording
  A.editIndex=math.max(1,math.min(r and #r.points or 1,(A.editIndex or 1)+1)); U.Refresh()
 end
 function actions.pointUp()
  local i=A.editIndex or 1; if A.editor and A.editor:Reorder(i,i-1) then A.editIndex=i-1 end; U.Refresh()
 end
 function actions.pointDown()
  local i=A.editIndex or 1; if A.editor and A.editor:Reorder(i,i+1) then A.editIndex=i+1 end; U.Refresh()
 end
 function actions.deletePoint()
  if A.editor then A.editor:Delete(A.editIndex or 1); A.editIndex=math.max(1,math.min(A.editIndex or 1,#A.editor.draft.points)) end; U.Refresh()
 end
 function actions.loop() if A.editor then A.editor:SetLoop(not A.editor.draft.loop); U.Refresh() end end
 function actions.reverse()
  if A.editor then A.editor:Reverse(); A.editIndex=math.max(1,#A.editor.draft.points-(A.editIndex or 1)+1)
  elseif A.follower then A.follower:Reverse() end; U.Refresh()
 end
 function actions.start()
  if guard() then return end
  local r=A.selectedRoute and A.db.routes[A.selectedRoute]; local p=position()
  if not r or not p or r.mapID~=p.mapID or not A.Client.Distance(p,r.points[1]) then say('Select a route in your current zone with readable position and distance data.'); return end
  A.follower=A.Follower.New(r,p,A.Client.Distance,{arrival=A.db.settings.arrival})
  A.mapPreviewRoute=nil
  if A.Map and A.Map.SetNodeFocus then A.Map.SetNodeFocus(nil) end
  U.frame:Hide()
  say(r.generated and 'Following direct connections. Use edited detours where needed.' or 'Following your route.')
 end
 function actions.pause()
  local f=A.follower; if f then if f.status=='paused' then f:Resume() else f:Pause() end end; U.Refresh()
 end
 function actions.skip() if A.follower then A.follower:Skip() end; U.Refresh() end
 function actions.stop()
  if A.follower then A.follower:Stop(); A.follower=nil end
  if A.Arrow then A.Arrow.Update(nil,nil,nil,A.Client.Distance) end
  if A.Map then A.Map.Refresh(A.db,U.DisplayRoute(),nil) end
  U.Refresh()
 end
 function actions.arrival()
  local value=(tonumber(A.db.settings.arrival) or 15)+5;actions.arrivalValue(nil,value>40 and 5 or value)
 end
 function actions.arrowScale() A.db.settings.arrowScale=(tonumber(A.db.settings.arrowScale) or 1)+.2; if A.db.settings.arrowScale>1.81 then A.db.settings.arrowScale=.8 end; U.Refresh() end
 function actions.arrivalValue(_,value)
  if U.syncingOptions or not A.Store.Number(value) then return end
  A.db.settings.arrival=math.max(5,math.min(40,math.floor(value/5+.5)*5))
  if A.follower then A.follower:SetArrival(A.db.settings.arrival) end
  U.Refresh()
 end
 function actions.arrowScaleValue(_,value)
  if U.syncingOptions or not A.Store.Number(value) then return end
  A.db.settings.arrowScale=math.max(.6,math.min(2,math.floor(value*10+.5)/10));U.Refresh()
 end
 function actions.arrowProgress()
  A.db.settings.arrowProgress=A.db.settings.arrowProgress==false
  if A.Arrow then A.Arrow.UpdateProgress(A.follower and A.follower:Snapshot()) end
  U.Refresh()
 end
 function actions.minimapButton()
  A.db.settings.minimapButton=A.db.settings.minimapButton==false
  if A.MinimapButton then A.MinimapButton.Refresh() end
  U.Refresh()
 end
 function actions.arrowNodeName()
  A.db.settings.arrowNodeName=A.db.settings.arrowNodeName~=true
  if A.Arrow then A.Arrow.UpdateName(A.follower and A.follower:Target()) end
  U.Refresh()
 end
 function actions.resetArrow()
  A.db.settings.arrowAnchor=nil; A.db.settings.arrowScale=1
  if A.Arrow and A.Arrow.frame then A.Arrow.frame:ClearAllPoints(); A.Arrow.frame:SetPoint('CENTER',UIParent,'CENTER',0,140); A.Arrow.frame:SetScale(1) end
  say('Arrow position and scale reset.')
 end
 local function markerChange(key,value)
  local s=A.Resources.Settings(A.db.settings);s[key]=value;A.Resources.Settings(A.db.settings)
  U.Refresh();if A.Map then A.Map.Refresh(A.db,U.DisplayRoute(),A.editor and nil or A.follower) end
 end
 function actions.nodeWorld() local s=A.Resources.Settings(A.db.settings);markerChange('world',not s.world) end
 function actions.nodeMini() local s=A.Resources.Settings(A.db.settings);markerChange('mini',not s.mini) end
 function actions.nodeRouteLine() local s=A.Resources.Settings(A.db.settings);markerChange('routeLines',not s.routeLines) end
 function actions.nodeOutline(value) if value=='ring' or value=='square' or value=='none' then markerChange('outline',value) end end
 function actions.nodeIcon() local s=A.Resources.Settings(A.db.settings);markerChange('icon',not s.icon) end
 function actions.nodeOutlineSize(value) if A.Store.Number(value) then markerChange('outlineSize',value) end end
 function actions.nodeIconSize(value) if A.Store.Number(value) then markerChange('iconSize',value) end end
 function actions.nodeDistance(value) if A.Store.Number(value) then markerChange('hideDistance',value) end end
 local function opacity(key,value)
  if U.syncingOptions or not A.Store.Number(value) then return end
  markerChange(key,math.floor(math.max(0,math.min(100,value))/5+.5)*.05)
 end
 function actions.nodeWorldOpacity(_,value) opacity('worldIconOpacity',value) end
 function actions.nodeMiniIconOpacity(_,value) opacity('miniIconOpacity',value) end
 function actions.nodeOutlineOpacity(_,value) opacity('miniOutlineOpacity',value) end
 function actions.import() if A.Import then A.Import() end end
 function actions.allMaterials() A.db.settings.materials=nil; U.Refresh() end
 function actions.prevMaterials() U.materialPage=math.max(1,U.materialPage-1); U.Refresh() end
 function actions.nextMaterials() U.materialPage=U.materialPage+1; U.Refresh() end
 function actions.prevRoute() U.routePage=math.max(1,U.routePage-1); U.Refresh() end
 function actions.nextRoute() U.routePage=U.routePage+1; U.Refresh() end
 function actions.map(keepPanel)
  if not WorldMapFrame then say('World map unavailable.'); return end
  local r=A.recording or U.PreviewRoute(); local p=A.Client.Position(); local id=U.tab=='atlas' and p and p.mapID or r and r.mapID or p and p.mapID
  A.mapPreviewRoute=nil
  if A.Map and A.Map.SetNodeFocus then A.Map.SetNodeFocus(nil) end
  WorldMapFrame:Show(); if id and WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(id) end
  if A.editor then
   if A.Map then A.Map.Refresh(A.db,A.editor.draft,nil) end
   if keepPanel~=true then U.frame:Hide() end
  end
 end
 return actions
end
