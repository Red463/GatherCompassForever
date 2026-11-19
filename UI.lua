local _, A = ...
local S=A.Skin
local U={controls={},routePage=1,tab='routes',compact=false}; A.UI=U
local W,H=960,624
local ROUTES_PER_PAGE=6
local function safe(v) return tostring(v or ''):gsub('|','||') end
local function place(f,parent,x,y,w,h)
 f:ClearAllPoints(); f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y); if w and h then f:SetSize(w,h) end; return f
end
local function label(parent,text,x,y,w,h,size,color,heading)
 return place(S.Label(parent,text,size or 12,color,heading),parent,x,y,w,h)
end
local function show(f,on) if on then f:Show() else f:Hide() end end
local function button(parent,key,text,x,y,w,h,style,fn)
 if style~='quiet' and style~='card' then h=math.min(h or 26,26) end
 local f=place(S.Button(parent,text,fn or U.actions[key],style),parent,x,y,w,h or 26); U.controls[key]=f; return f
end
local function check(parent,key,text,x,y,width,fn)
 local f=place(S.Check(parent,text,fn or U.actions[key]),parent,x,y,24,24)
 f.label:SetWidth(width);f:SetHitRectInsets(0,-width-4,0,0);U.controls[key]=f;return f
end
local function dropdown(parent,key,choices,x,y,width,fn,format)
 local f=place(S.Dropdown(parent,choices,fn or U.actions[key],format),parent,x,y,width,26)
 U.controls[key]=f;return f
end
local function choices(values,unit)
 local result={};for _,value in ipairs(values) do result[#result+1]={value=value,label=tostring(value)..(unit or '')} end;return result
end
function U.ZoneName(id)
 local info=id and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(id)
 return info and info.name or (id and 'Zone '..id or 'Position unavailable')
end
function U.Filter() return A.Selection.Filter(A.db.settings) end
function U.SelectedNodes() local p=A.Client.Position(); return A.Store.Select(A.db,p and p.mapID,U.Filter()) end
function U.FiltersChanged()
 U.Refresh()
 if A.Map then A.Map.SetNodeFocus(nil);A.Map.Refresh(A.db,U.DisplayRoute(),A.editor and nil or A.follower) end
end
function U.SetSource(v)
 if v~='combined' and v~='confirmed' and v~='imported' and v~='none' then return end
 A.db.settings.source=v;U.FiltersChanged()
end
function U.SetKind(v)
 if v~='both' and v~='herb' and v~='ore' and v~='none' then return end
 A.db.settings.kind=v;U.FiltersChanged()
end
function U.ToggleSource(key) A.Selection.ToggleSource(A.db.settings,key);U.FiltersChanged() end
function U.ToggleKind(key) A.Selection.ToggleKind(A.db.settings,key);U.FiltersChanged() end
function U.ToggleMaterial(id)
 A.Selection.ToggleMaterial(A.db,id);U.FiltersChanged()
end
function U.BulkMaterials(mode,on) local skills,context=A.Resources.Skills();A.Selection.Bulk(A.db,mode,on,skills,context);U.FiltersChanged() end
function U.Edit(route)
 A.editor=A.Editor.New(route); A.editIndex=1
 A.mapPreviewRoute=nil
 U.frame:Show()
 if A.Map then A.Map.SetEditor(A.editor) end; U.compact=false; U.tab='routes'; U.Refresh()
end
function U.SelectRoute(id)
 if A.editor or A.recording or A.recordedDraft then A.status='Save or discard the current work before selecting another route.'; U.Refresh(); return end
 if not A.db.routes[id] then return end
 if A.follower and (A.follower.status=='complete' or A.follower.status=='stopped') then A.follower=nil end
 A.selectedRoute=id; A.mapPreviewRoute=nil; U.Refresh()
end
function U.PreviewRoute() return A.plan and A.plan.route or A.selectedRoute and A.db.routes[A.selectedRoute] end
function U.DisplayRoute()
 if A.editor then return A.editor.draft end
 if A.follower and A.follower.status~='complete' and A.follower.status~='stopped' then return A.follower.route end
 return A.plan and A.plan.review and A.plan.route or nil
end
function U.SetTab(tab) if tab=='atlas' or tab=='resources' then tab='codex' end;if tab=='welcome' or tab=='routes' or tab=='codex' or tab=='nodes' or tab=='settings' then S.CloseDropdown();U.tab=tab end; U.Refresh() end
function U.SetCompact(on) S.CloseDropdown();U.compact=not not on; U.Refresh(); U.frame:Show() end
local function buildHeader()
 U.header=place(CreateFrame('Frame',nil,U.frame),U.frame,12,2,936,60)
 U.header:SetFrameLevel(U.frame:GetFrameLevel()+2)
 U.zone=label(U.header,'',68,34,776,20,12,S.muted)
 U.header:EnableMouse(true); U.header:RegisterForDrag('LeftButton')
 U.header:SetScript('OnDragStart',function() U.frame:StartMoving() end); U.header:SetScript('OnDragStop',function() U.frame:StopMovingOrSizing() end)
 button(U.header,'minimize','-',864,2,25,22,'subtle')
 U.controls.close=U.chrome.CloseButton; U.controls.close:SetScript('OnClick',U.actions.close)
 U.controls.close:SetFrameLevel(math.max(U.controls.close:GetFrameLevel(),U.header:GetFrameLevel()+2))
 S.Hint(U.controls.minimize,'Minimise','Keep only the navigation bar visible.')
 U.nav=place(CreateFrame('Frame',nil,U.frame),U.frame,12,64,936,32);U.nav.topTabs=true;U.nav:SetFrameLevel(U.header:GetFrameLevel()+1);U.tabs={}
 for i,t in ipairs({{'welcome','Welcome',154},{'routes','Routes',154},{'codex','Node Codex',154},{'nodes','Node display',154},{'settings','Preferences',154}}) do
  local b=S.Tab(U.nav,t[2],t[3],function() U.SetTab(t[1]) end,true)
  place(b,U.nav,8+(i-1)*164,0,t[3],32);U.tabs[t[1]]=b;U.controls['tab'..t[1]]=b
 end
end
local function buildSidebar()
 U.filterSidebar=A.FilterSidebar.New(U.body,U);U.sidebar=U.filterSidebar.frame
 U.materialRows=U.filterSidebar.rows;U.materialEmpty=U.filterSidebar.empty;U.sourceCounts=U.filterSidebar.count
end
local function buildPreferences()
 U.preferences=place(CreateFrame('Frame',nil,U.content),U.content,20,19,710,377)
 label(U.preferences,'Options',0,0,600,26,18,S.gold,true)
 local function rule(y) local t=S.Fill(U.preferences,{.35,.30,.22,1},'ARTWORK');place(t,U.preferences,0,y,710,1) end
 rule(42);label(U.preferences,'Navigation',12,58,670,22,15,S.gold,true)
 label(U.preferences,'Waypoint arrival distance',20,103,210,24,13,S.text)
 U.controls.arrival=place(S.Slider(U.preferences,5,40,5,U.actions.arrivalValue),U.preferences,248,109,270,18)
 U.arrivalValue=label(U.preferences,'',554,103,140,24,13,S.gold)
 label(U.preferences,'Applies immediately, including during a route.',20,149,670,18,12,S.muted)
 rule(176);label(U.preferences,'Guide arrow',12,192,670,22,15,S.gold,true)
 label(U.preferences,'Arrow scale',20,232,210,24,13,S.text)
 U.controls.arrowScale=place(S.Slider(U.preferences,.6,2,.1,U.actions.arrowScaleValue,function(v) return string.format('%d%%',v*100+.5) end),U.preferences,248,238,270,18)
 U.arrowScaleValue=label(U.preferences,'',554,232,140,24,13,S.gold)
 U.controls.arrowProgress=place(S.Check(U.preferences,'Show route step and lap',U.actions.arrowProgress),U.preferences,18,286,24,24)
 S.Hint(U.controls.arrowProgress,'Arrow progress','Show the waypoint number and current lap. Laps start at 1 when following a loop.')
 U.controls.arrowNodeName=place(S.Check(U.preferences,'Show next node name',U.actions.arrowNodeName),U.preferences,18,314,24,24)
 S.Hint(U.controls.arrowNodeName,'Next node name','Show the next resource below the distance. Unnamed path points show Travel waypoint; gather points without a known name show Gathering stop.')
 button(U.preferences,'resetArrow','Reset position & scale',474,286,220,24,'subtle')
 U.controls.minimapButton=place(S.Check(U.preferences,'Show minimap button',U.actions.minimapButton),U.preferences,472,314,24,24)
 U.controls.minimapButton.label:SetWidth(200)
 S.Hint(U.controls.minimapButton,'Minimap launcher','Show the compass button beside your minimap. Click it to toggle this panel; drag it to reposition. Use /gcf to reopen the panel when the button is hidden.')
 local hint=label(U.preferences,'Drag the guide arrow to move it. Click it to reopen this window.',20,350,670,20,12,S.muted);hint:SetWordWrap(true)
end
local function buildNodeOptions() U.nodeDisplayView=A.NodeDisplayView.New(U.content,U);U.nodeOptions=U.nodeDisplayView.frame end
local function buildFooter()
 U.footer=place(S.Panel(U.frame,{.075,.125,.085,1},{.27,.34,.24,1}),U.frame,1,552,958,68)
 local icon=S.Image(U.footer,'Icon',42,42); place(icon,U.footer,14,13,42,42)
 U.footerName=label(U.footer,'',68,14,340,21,14,S.text); U.footerMeta=label(U.footer,'',68,38,370,17,11,S.muted)
 button(U.footer,'start','> Start route',790,18,150,32,'primary'); button(U.footer,'pause','Pause',790,18,150,32,'primary')
 button(U.footer,'skip','Skip >',710,18,70,32,'subtle'); button(U.footer,'stop','Stop',640,18,60,32,'subtle')
 button(U.footer,'followReverse','Reverse',551,18,79,32,'quiet',U.actions.reverse)
 button(U.footer,'workReturn','Return to draft',760,18,180,32,'gold'); button(U.footer,'expand','+',914,19,28,30,'quiet')
 U.footer:EnableMouse(true); U.footer:RegisterForDrag('LeftButton')
 U.footer:SetScript('OnDragStart',function() if U.compact then U.frame:StartMoving() end end); U.footer:SetScript('OnDragStop',function() U.frame:StopMovingOrSizing() end)
 U.status=label(U.frame,'',18,623,924,25,10,S.muted); U.status:SetWordWrap(true)
 U.statusHover=place(CreateFrame('Frame',nil,U.frame),U.frame,14,621,932,28); U.statusHover:EnableMouse(true)
 S.Hint(U.statusHover,'Gather Compass status',function() return U.status:GetText() end)
end
local function buildWindow()
 U.actions=A.UIActions.Bind(U)
 U.tab=A.db.settings.welcomeSeen==true and 'routes' or 'welcome'
 U.frame=CreateFrame('Frame','GatherCompassForeverWindow',UIParent);U.frame:Hide()
 U.compactBackground=S.Panel(U.frame);U.compactBackground:SetAllPoints()
 U.chrome=S.Window(U.frame);U.chrome:SetAllPoints();U.chrome:SetFrameLevel(U.frame:GetFrameLevel()); U.frame:SetPoint('CENTER',UIParent,'CENTER',0,0)
 U.frame:EnableMouse(true);U.frame:SetFrameStrata('DIALOG'); U.frame:SetClampedToScreen(true); U.frame:SetMovable(true); S.FitWindow(U.frame,W,H); buildHeader()
 U.body=place(CreateFrame('Frame',nil,U.frame),U.frame,12,100,936,414); buildSidebar()
 U.content=place(CreateFrame('Frame',nil,U.body),U.body,194,0,742,414)
 U.routeView=A.RouteView.New(U.content,U);U.library=U.routeView.frame;buildPreferences(); buildNodeOptions(); buildFooter()
 U.codexView=A.ResourceLibraryView.New(U.content,U);U.resourceLibraryView=U.codexView
 U.welcomeView=A.WelcomeView.New(U.content,U)
 if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='GatherCompassForeverWindow' end
 U.frame:HookScript('OnHide',function() S.CloseDropdown() end)
 U.frame:RegisterEvent('DISPLAY_SIZE_CHANGED'); U.frame:RegisterEvent('UI_SCALE_CHANGED'); U.frame:SetScript('OnEvent',function() U.RefreshMode() end)
 U.Refresh(); U.frame:Hide()
end
function U.Build()
 if U.built then return true end
 if U.buildError then return nil,U.buildError end
 if not CreateFrame then return nil,'Frame API unavailable.' end
 local ok,reason=pcall(buildWindow)
 if not ok then
  U.buildError=tostring(reason);if U.frame then U.frame:Hide() end
  return nil,U.buildError
 end
 U.built=true;return true
end
function U.RefreshMode()
 local compact=U.compact; local width=compact and 730 or W
 S.FitWindow(U.frame,width,compact and 98 or H)
 show(U.chrome,not compact);show(U.compactBackground,compact);show(U.header,not compact); show(U.nav,not compact); show(U.body,not compact)
 place(U.footer,U.frame,compact and 1 or 12,compact and 1 or 520,width-(compact and 2 or 24),64)
 place(U.status,U.frame,18,compact and 72 or 588,width-36,25); place(U.statusHover,U.frame,14,compact and 70 or 586,width-28,28)
 local shift=compact and 36 or 24
 for _,key in ipairs({'start','pause'}) do place(U.controls[key],U.footer,width-170-shift,18,150,26) end
 place(U.controls.skip,U.footer,width-250-shift,18,70,26); place(U.controls.stop,U.footer,width-320-shift,18,60,26)
 place(U.controls.followReverse,U.footer,width-409-shift,18,79,26); place(U.controls.expand,U.footer,width-45,19,28,30)
 place(U.controls.workReturn,U.footer,width-200-shift,18,180,26)
 U.footerName:SetWidth(compact and 250 or 340); U.footerMeta:SetWidth(compact and 280 or 370)
end
local function refreshSidebar(p) U.filterSidebar.Refresh(p) end
local function refreshFooter(p)
 local f=A.follower;local active=f and (f.status=='running' or f.status=='paused' or f.status=='suspended')
 local r=active and f.route or A.plan and A.plan.route or A.selectedRoute and A.db.routes[A.selectedRoute]
 U.footerName:SetText(safe(r and r.name or 'Ready to farm'))
 local detail='Choose materials, then Generate & start or Generate & review.'
 if active then detail=(f.status=='paused' and 'Paused' or f.status=='suspended' and 'Guidance suspended' or 'Following route')..' / '..f.index..' of '..#r.points..(r.loop and (' / Lap '..(f.lap+1)) or '')
 elseif r then detail='Ready to follow / Join at the nearest route point' end
 U.footerMeta:SetText(detail)
 show(U.controls.start,not active);show(U.controls.pause,active);show(U.controls.skip,active);show(U.controls.stop,active)
 show(U.controls.followReverse,active and not U.compact);show(U.controls.expand,U.compact);show(U.controls.workReturn,false)
 U.controls.pause:SetText(f and f.status=='paused' and 'Resume' or 'Pause')
 U.controls.start:SetEnabled(r~=nil and p~=nil and r.mapID==p.mapID and A.Client.Distance(p,r.points[1])~=nil)
end
local function refreshStatus(p)
 local text=A.status or 'Ready. Gather normally to remember your discoveries.'
 if A.detector and A.detector.reason then text=A.detector.reason end; if A.follower and A.follower.reason then text=A.follower.reason end
 local cap=A.Client.Probe(); local missing={}
 if not p then missing[#missing+1]='Position unavailable: capture and guidance are suspended' end
 if not cap.loot then missing[#missing+1]='Gather capture needs loot APIs' end
 if not cap.facing then missing[#missing+1]='Arrow needs readable facing' end
 if not cap.distance then missing[#missing+1]='Route distance unavailable' end
 if not cap.minimap then missing[#missing+1]='Minimap line needs view radius' end
 if #missing>0 then text=table.concat(missing,'; ')..'. '..text end; if A.storageReason then text=A.storageReason..' '..text end
 U.status:SetText(safe(text))
end
function U.Refresh()
 if not U.frame or not A.db then return end
 if not U.frame:IsShown() then return end
 local p=A.Client.Position(); local work=A.editor or A.recording or A.recordedDraft
 if U.compact then U.RefreshMode(); refreshFooter(p); refreshStatus(p); return end
 local resource=U.tab=='codex';local welcome=U.tab=='welcome';local full=resource or welcome or U.tab=='nodes';local nodes=full and {} or U.SelectedNodes()
 show(U.sidebar,not full);place(U.content,U.body,full and 0 or 194,0,full and 936 or 742,414)
 U.RefreshMode(); for id,b in pairs(U.tabs) do S.Selected(b,id==U.tab) end
 show(U.library,U.tab=='routes'); show(U.preferences,U.tab=='settings'); show(U.nodeOptions,U.tab=='nodes')
 show(U.resourceLibraryView.frame,resource)
 show(U.welcomeView.frame,welcome)
 if not full then refreshSidebar(p) end
 if U.tab=='routes' then U.routeView.Refresh() elseif resource then U.resourceLibraryView.Refresh() elseif welcome then U.welcomeView.Refresh(p);A.db.settings.welcomeSeen=true end
 refreshFooter(p); refreshStatus(p)
 U.nodeDisplayView.Refresh()
 U.syncingOptions=true
 U.controls.arrival:SetValue(A.db.settings.arrival or 15);U.controls.arrowScale:SetValue(tonumber(A.db.settings.arrowScale) or 1)
 U.syncingOptions=false
 U.arrivalValue:SetText((A.db.settings.arrival or 15)..' yards');U.arrowScaleValue:SetText(math.floor((tonumber(A.db.settings.arrowScale) or 1)*100+.5)..'%')
 U.controls.arrowProgress:SetChecked(A.db.settings.arrowProgress~=false)
 U.controls.arrowNodeName:SetChecked(A.db.settings.arrowNodeName==true)
 U.controls.minimapButton:SetChecked(A.db.settings.minimapButton~=false)
end
function U.Toggle() local ready,reason=U.Build();if not ready then return nil,reason end;if U.frame:IsShown() then U.frame:Hide() else U.frame:Show(); U.Refresh() end end

function U.OpenRoutes() local ready,reason=U.Build();if not ready then return nil,reason end;U.compact=false; U.tab='routes'; U.frame:Show(); U.Refresh() end
