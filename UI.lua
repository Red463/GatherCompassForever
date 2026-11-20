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
function U.MarkerFilter() return A.Selection.EffectiveMarker(A.db.settings,A.follower) end
function U.SelectedNodes() local p=A.Client.Position(); return A.Store.Select(A.db,p and p.mapID,U.Filter()) end
function U.FiltersChanged()
 U.Refresh()
 if A.Map then A.Map.Refresh(A.db,U.DisplayRoute(),A.editor and nil or A.follower) end
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
function U.SetTab(tab) if U.routeSketch then U.routeSketch.picker:Close() end;if tab=='atlas' or tab=='resources' then tab='codex' end;if tab=='welcome' or tab=='routes' or tab=='codex' or tab=='nodes' or tab=='history' or tab=='settings' then S.CloseDropdown();U.tab=tab end; U.Refresh() end
function U.SetCompact(on) if U.window then U.window:Cancel() end;S.CloseDropdown();U.compact=not not on; U.Refresh(); U.frame:Show() end
local function buildHeader()
 U.header=place(CreateFrame('Frame',nil,U.frame),U.frame,12,2,936,60)
 U.header:SetFrameLevel(U.frame:GetFrameLevel()+2)
 U.zone=label(U.header,'',68,34,776,20,12,S.muted)
 U.header:EnableMouse(true); U.header:RegisterForDrag('LeftButton')
 U.header:SetScript('OnDragStart',function() U.window:StartMoving() end); U.header:SetScript('OnDragStop',function() U.window:StopMoving() end)
 button(U.header,'minimize','-',864,2,25,22,'subtle')
 U.controls.close=U.chrome.CloseButton; U.controls.close:SetScript('OnClick',U.actions.close)
 U.controls.close:SetFrameLevel(math.max(U.controls.close:GetFrameLevel(),U.header:GetFrameLevel()+2))
 S.Hint(U.controls.minimize,'Minimise','Keep only the navigation bar visible.')
 U.nav=place(CreateFrame('Frame',nil,U.frame),U.frame,12,64,936,32);U.nav.topTabs=true;U.nav:SetFrameLevel(U.header:GetFrameLevel()+1);U.tabs={}
 for i,t in ipairs({{'welcome','Welcome',130},{'routes','Routes',130},{'codex','Node Codex',130},{'nodes','Node display',130},{'history','History',130},{'settings','Preferences',130}}) do
  local b=S.Tab(U.nav,t[2],t[3],function() U.SetTab(t[1]) end,true)
  place(b,U.nav,8+(i-1)*164,0,t[3],32);U.tabs[t[1]]=b;U.controls['tab'..t[1]]=b
 end
end
local function buildSidebar()
 U.filterSidebar=A.FilterSidebar.New(U.body,U);U.sidebar=U.filterSidebar.frame
 U.materialRows=U.filterSidebar.rows;U.materialEmpty=U.filterSidebar.empty;U.sourceCounts=U.filterSidebar.count
end
local function buildPreferences()
 U.preferencesView=A.PreferencesView.New(U.content,U);U.preferencesViewport=U.preferencesView.frame;U.preferencesScroll=U.preferencesView.scroller;U.preferences=U.preferencesScroll.body
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
 U.footer:SetScript('OnDragStart',function() if U.compact then U.window:StartMoving() end end); U.footer:SetScript('OnDragStop',function() U.window:StopMoving() end)
 U.status=label(U.frame,'',18,623,924,25,10,S.muted); U.status:SetWordWrap(true)
 U.statusHover=place(CreateFrame('Frame',nil,U.frame),U.frame,14,621,932,28); U.statusHover:EnableMouse(true)
 S.Hint(U.statusHover,'Gatherly status',function() return U.status:GetText() end)
end
local function buildWindow()
 A.Selection.Init(A.db.settings)
 U.actions=A.UIActions.Bind(U)
 U.tab=A.db.settings.welcomeSeen==true and 'routes' or 'welcome'
 U.frame=CreateFrame('Frame','GatherlyWindow',UIParent);U.frame:Hide()
 U.compactBackground=S.Panel(U.frame);U.compactBackground:SetAllPoints()
 U.chrome=S.Window(U.frame);U.chrome:SetAllPoints();U.chrome:SetFrameLevel(U.frame:GetFrameLevel()); U.frame:SetPoint('CENTER',UIParent,'CENTER',0,0)
 U.frame:EnableMouse(true);U.frame:SetFrameStrata('DIALOG'); U.frame:SetClampedToScreen(true); U.frame:SetMovable(true); U.window=A.PanelWindow.New(U);U.window:Apply(); buildHeader()
 U.body=place(CreateFrame('Frame',nil,U.frame),U.frame,12,100,936,414); buildSidebar()
 U.content=place(CreateFrame('Frame',nil,U.body),U.body,194,0,742,414)
 U.routeView=A.RouteView.New(U.content,U);U.library=U.routeView.frame;buildPreferences(); buildNodeOptions(); buildFooter()
 U.codexView=A.ResourceLibraryView.New(U.content,U);U.resourceLibraryView=U.codexView
 U.welcomeView=A.WelcomeView.New(U.content,U)
 U.historyView=A.HistoryView.New(U.content,U)
 if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='GatherlyWindow' end
 U.frame:HookScript('OnHide',function() S.CloseDropdown();U.routeSketch.picker:Close() end)
 U.frame:RegisterEvent('DISPLAY_SIZE_CHANGED'); U.frame:RegisterEvent('UI_SCALE_CHANGED'); U.frame:SetScript('OnEvent',function() U.window:Cancel();U.Refresh() end)
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
 local compact=U.compact;local width,height=U.window:Apply()
 place(U.header,U.frame,12,2,width-24,60);place(U.zone,U.header,68,34,width-160,20)
 place(U.controls.minimize,U.header,width-96,2,25,22)
 place(U.nav,U.frame,12,64,width-24,32)
 local tabWidth=math.min(154,(width-60)/6-10)
 local index=0;for _,id in ipairs({'welcome','routes','codex','nodes','history','settings'}) do
  local tab=U.tabs[id];place(tab,U.nav,8+index*(tabWidth+10),0,tabWidth,32)
  tab.label:SetWidth(tabWidth-16);index=index+1
 end
 place(U.body,U.frame,12,100,width-24,math.max(1,height-210))
 local full=U.tab~='routes';place(U.content,U.body,full and 0 or 194,0,width-24-(full and 0 or 194),math.max(1,height-210))
 local layoutKey=width..':'..height..':'..U.codexView.mode..':'..U.nodeDisplayView.page
 if not compact and U.layoutsKey~=layoutKey then
  U.filterSidebar:Layout(194,height-210)
  U.routeView.Layout(width-218,height-210)
  U.codexView.Layout(width-24,height-210);U.nodeDisplayView.Layout(width-24,height-210);U.welcomeView.Layout(width-24,height-210)
  U.preferencesView.Layout(width-24,height-210)
  U.historyView.Layout(width-24,height-210)
  U.layoutsKey=layoutKey
 end
 show(U.chrome,not compact);show(U.compactBackground,compact);show(U.header,not compact); show(U.nav,not compact); show(U.body,not compact)
 place(U.footer,U.frame,compact and 1 or 12,compact and 1 or height-104,width-(compact and 2 or 24),64)
 place(U.status,U.frame,18,compact and 72 or height-36,width-36,25); place(U.statusHover,U.frame,14,compact and 70 or height-38,width-28,28)
 local shift=compact and 36 or 24
 for _,key in ipairs({'start','pause'}) do place(U.controls[key],U.footer,width-170-shift,18,150,26) end
 place(U.controls.skip,U.footer,width-250-shift,18,70,26); place(U.controls.stop,U.footer,width-320-shift,18,60,26)
 place(U.controls.followReverse,U.footer,width-409-shift,18,79,26); place(U.controls.expand,U.footer,width-45,19,28,30)
 place(U.controls.workReturn,U.footer,width-200-shift,18,180,26)
 local active=A.follower and (A.follower.status=='running' or A.follower.status=='paused' or A.follower.status=='suspended')
 U.footerName:SetWidth(compact and 250 or math.max(140,width-(active and 530 or 300)))
 U.footerMeta:SetWidth(compact and 280 or math.max(140,width-(active and 530 or 300)))
end
local function refreshSidebar(p) U.filterSidebar.Refresh(p) end
local function refreshFooter(p)
 local f=A.follower;local active=f and (f.status=='running' or f.status=='paused' or f.status=='suspended')
 local session=A.sessions and A.sessions:Active()
 local r=active and f.route or A.plan and A.plan.route or A.selectedRoute and A.db.routes[A.selectedRoute]
 U.footerName:SetText(safe(r and r.name or session and session.routeName or 'Ready to farm'))
 local detail='Choose materials, then Generate & start or Generate & review.'
 if active then detail=(f.status=='paused' and 'Paused' or f.status=='suspended' and 'Guidance suspended' or 'Following route')..' / '..f.index..' of '..#r.points..(r.loop and (' / Lap '..(f.lap+1)) or '')
 elseif session then detail='Session in progress / Press Stop to save its summary'
 elseif r then detail='Ready to follow / Join at the nearest route point' end
 U.footerMeta:SetText(detail)
 show(U.controls.start,not active);show(U.controls.pause,active);show(U.controls.skip,active);show(U.controls.stop,active or session~=nil)
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
 if A.RouteControls and A.db then A.RouteControls.Update(A.follower) end
 if not U.frame or not A.db then return end
 if not U.frame:IsShown() then return end
 local p=A.Client.Position(); local work=A.editor or A.recording or A.recordedDraft
 if U.compact then U.RefreshMode(); refreshFooter(p); refreshStatus(p); return end
 local resource=U.tab=='codex';local welcome=U.tab=='welcome';local full=U.tab~='routes';local nodes=full and {} or U.SelectedNodes()
 show(U.sidebar,not full);place(U.content,U.body,full and 0 or 194,0,full and 936 or 742,414)
 U.RefreshMode(); for id,b in pairs(U.tabs) do S.Selected(b,id==U.tab) end
 show(U.library,U.tab=='routes'); show(U.preferencesViewport,U.tab=='settings'); show(U.nodeOptions,U.tab=='nodes')
 show(U.resourceLibraryView.frame,resource)
 show(U.welcomeView.frame,welcome)
 show(U.historyView.frame,U.tab=='history')
 if not full then refreshSidebar(p) elseif U.tab=='settings' then U.zone:SetText('Preferences  -  Panel and guide options') elseif U.tab=='history' then U.zone:SetText('History  -  This character\'s route sessions') end
 if U.tab=='routes' then U.routeView.Refresh() elseif resource then U.resourceLibraryView.Refresh() elseif welcome then U.welcomeView.Refresh(p);A.db.settings.welcomeSeen=true end
 if U.tab=='history' then U.historyView.Refresh() end
 refreshFooter(p); refreshStatus(p)
 U.nodeDisplayView.Refresh()
 U.preferencesView.Refresh()
end
function U.Toggle() local ready,reason=U.Build();if not ready then return nil,reason end;if U.frame:IsShown() then U.frame:Hide() else U.frame:Show(); U.Refresh() end end

function U.OpenRoutes() local ready,reason=U.Build();if not ready then return nil,reason end;U.compact=false; U.tab='routes'; U.frame:Show(); U.Refresh() end
function U.OpenHistory(id)
 local ready,reason=U.Build();if not ready then return nil,reason end
 U.compact=false;U.tab='history';U.historyView.selectedID=id;U.frame:Show();U.Refresh()
end
