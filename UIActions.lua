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
 local function refreshMap()
  if A.Map then A.Map.SetNodeFocus(nil);A.Map.Refresh(A.db,U.DisplayRoute(),A.follower) end
 end
 local function clearArrow() if A.Arrow then A.Arrow.Update(nil,nil,nil,A.Client.Distance) end end
 function U.ReviewNodes(nodes,player,startNow)
  player=player or A.Client.Position()
  local plan,reason=A.FarmingSession.New(nodes,player,A.Client.Distance,{zoneName=U.ZoneName(player and player.mapID),routes=A.db.routes,filter=U.Filter()})
  if not plan then say(reason);return nil end
  A.plan=plan;A.follower=nil;A.editor=nil;A.mapPreviewRoute=nil;clearArrow()
  if A.Map and A.Map.SetEditor then A.Map.SetEditor(nil) end
  U.tab='routes';U.compact=false;U.frame:Show()
  if startNow then actions.start() else refreshMap();say(reason) end
  return true
 end
 function actions.generateStart() return U.ReviewNodes(U.SelectedNodes(),nil,true) end
 function actions.generateReview() return U.ReviewNodes(U.SelectedNodes()) end
 function actions.selectNode(key)
  if not A.plan or A.plan.excluded[key] then return end
  for _,n in ipairs(A.plan.candidates) do if A.FarmingSession.Key(n)==key then A.plan.selected=key;U.Refresh();return end end
 end
 local function rebuild(method)
  local plan=A.plan;if not plan then return end
  local old=A.follower;local ok,reason=plan[method](plan,method=='Remove' and plan.selected or A.Client.Position(),method=='Remove' and A.Client.Position() or nil)
  if not ok then say(reason);return end
  if old and old.status~='complete' and old.status~='stopped' then
   A.follower=nil
   if plan.route then
    A.follower=A.Follower.New(plan.route,A.Client.Position(),A.Client.Distance,{arrival=A.db.settings.arrival})
    A.follower.lap=old.lap;if old.status=='paused' then A.follower:Pause() end
   else clearArrow();plan.review=true end
  else plan.review=true end
  refreshMap();say(plan.message)
 end
 function actions.removeNode() rebuild('Remove') end
 function actions.undoNode() rebuild('Undo') end
 function actions.routeStyle(value)
  if value~='lines' and value~='heatmap' then return end
  A.db.settings.routeStyle=value;refreshMap();U.Refresh()
 end
 function actions.reverse() if A.follower then A.follower:Reverse() end;U.Refresh() end
 function actions.start()
  local r=A.plan and A.plan.route or A.selectedRoute and A.db.routes[A.selectedRoute];local p=position()
  if not r or not p or r.mapID~=p.mapID or not A.Client.Distance(p,r.points[1]) then say('Generate a route in your current zone with readable position and distance data.');return end
  local nearest
  for _,point in ipairs(r.points) do local d=A.Client.Distance(p,point);if d and (not nearest or d<nearest) then nearest=d end end
  if r.maxLink and (not nearest or nearest>r.maxLink) then say('Move nearer the reviewed area, or generate again from your current position.');return end
  A.follower=A.Follower.New(r,p,A.Client.Distance,{arrival=A.db.settings.arrival})
  if A.plan then A.plan.review=false end
  A.mapPreviewRoute=nil;refreshMap();U.frame:Hide()
  say('Following a local farming corridor. Terrain may require a detour.')
 end
 function actions.pause()
  local f=A.follower; if f then if f.status=='paused' then f:Resume() else f:Pause() end end; U.Refresh()
 end
 function actions.skip() if A.follower then A.follower:Skip() end; U.Refresh() end
 function actions.stop()
  if A.follower then A.follower:Stop(); A.follower=nil end
  if A.plan then A.plan.review=false end
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
