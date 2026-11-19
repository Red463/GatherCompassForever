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
 A.editor=A.Editor.New(route); A.editIndex=1; U.name:SetText(route.name or 'New route')
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
function U.PreviewRoute() return A.editor and A.editor.draft or A.recordedDraft or A.selectedRoute and A.db.routes[A.selectedRoute] end
function U.DisplayRoute()
 if A.editor then return A.editor.draft end
 if A.follower and A.follower.status~='complete' and A.follower.status~='stopped' then return A.follower.route end
 return nil
end
function U.SetTab(tab) if tab=='routes' or tab=='atlas' or tab=='resources' or tab=='nodes' or tab=='settings' then S.CloseDropdown();U.tab=tab end; U.Refresh() end
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
 for i,t in ipairs({{'routes','Routes',132},{'atlas','Node Atlas',132},{'resources','Resources',132},{'nodes','Node display',132},{'settings','Preferences',132}}) do
  local b=S.Tab(U.nav,t[2],t[3],function() U.SetTab(t[1]) end,true)
  place(b,U.nav,8+(i-1)*140,0,t[3],32);U.tabs[t[1]]=b;U.controls['tab'..t[1]]=b
 end
end
local function buildSidebar()
 U.filterSidebar=A.FilterSidebar.New(U.body,U);U.sidebar=U.filterSidebar.frame
 U.materialRows=U.filterSidebar.rows;U.materialEmpty=U.filterSidebar.empty;U.sourceCounts=U.filterSidebar.count
end
local function buildLibrary()
 U.library=place(CreateFrame('Frame',nil,U.content),U.content,20,19,710,377)
 label(U.library,'Routes',0,0,250,26,18,S.gold,true)
 U.libraryInfo=label(U.library,'',0,31,360,18,12,S.muted)
 button(U.library,'new','+ New route',396,1,96,29,'subtle'); button(U.library,'generate','Generate',500,1,94,29,'gold'); button(U.library,'record','Record trail',602,1,108,29,'subtle')
 U.cards={}; U.routeRows=U.cards
 for i=1,ROUTES_PER_PAGE do
  local b=button(U.library,'route'..i,'',0,66+(i-1)*46,252,45,'card',function(self) if self.routeID then U.SelectRoute(self.routeID) end end)
  b.label:ClearAllPoints(); place(b.label,b,10,4,232,18); b.label:SetJustifyH('LEFT')
  b.meta=label(b,'',10,24,232,16,11,S.muted)
  S.Hint(b,'Route details',function()
   local r=b.routeID and A.db.routes[b.routeID]
   return r and (r.name..' / '..U.ZoneName(r.mapID)..' / '..#r.points..' waypoints') or ''
  end)
  U.cards[i]=b
 end
 button(U.library,'prevRoute','<',0,357,26,23,'quiet'); button(U.library,'nextRoute','>',226,357,26,23,'quiet')
 U.routePageLabel=label(U.library,'',33,358,182,20,10,S.dim); U.routePageLabel:SetJustifyH('CENTER')
 U.detail=place(S.Panel(U.library),U.library,270,66,440,310)
 U.routeSketch=A.RouteSketch.New(U.detail); place(U.routeSketch.frame,U.detail,1,1,438,154)
 U.previewName=label(U.detail,'',14,167,326,22,16,S.text)
 U.routeType=label(U.detail,'',349,168,75,20,10,S.gold); U.routeType:SetJustifyH('RIGHT')
 U.previewMeta=label(U.detail,'',14,194,410,18,11,S.muted); U.statValues={}
 for i,t in ipairs({'WAYPOINTS','HERB STOPS','ORE STOPS'}) do
  local x=14+(i-1)*143; U.statValues[i]=label(U.detail,'',x+98,229,38,20,13,S.gold); label(U.detail,({'Waypoints:','Herb stops:','Ore stops:'})[i],x,229,96,20,12,S.muted)
 end
 button(U.detail,'edit','Edit path',14,275,126,26,'subtle');button(U.detail,'map','Open map',148,275,134,26,'subtle')
 button(U.detail,'deleteRoute','Delete route',290,275,134,26,'subtle')
 S.Hint(U.controls.deleteRoute,'Delete saved route','Remove this saved route after confirming its name. Known node locations are kept. Deleting the route you are following also stops its guidance.')
 U.empty=place(S.Panel(U.library,{.075,.12,.085,1},{.25,.32,.23,1}),U.library,0,66,710,310)
 local icon=S.Image(U.empty,'EmptyEmblem',96,96); icon:SetPoint('TOPLEFT',U.empty,'TOPLEFT',307,-16)
 local title=label(U.empty,'Your first trail starts here.',30,117,650,30,21,S.text,true); title:SetJustifyH('CENTER')
 local body=label(U.empty,'Gather a few herbs or ore, import known locations,\nor draw a route of your own.',80,157,550,46,13,S.muted); body:SetJustifyH('CENTER'); body:SetWordWrap(true)
 button(U.empty,'emptyImport','Import spawn points',202,224,158,30,'primary',U.actions.import)
 button(U.empty,'emptyNew','Draw a route',370,224,138,30,'subtle',U.actions.new)
 local hint=label(U.empty,'Your discoveries are remembered across characters.',60,276,590,16,10,S.dim); hint:SetJustifyH('CENTER')
end
local function buildWork()
 U.workPanel=place(CreateFrame('Frame',nil,U.content),U.content,20,19,710,377)
 U.workTitle=label(U.workPanel,'ROUTE EDITOR',0,0,300,24,18,S.gold,true)
 U.workSubtitle=label(U.workPanel,'',0,27,480,18,11,S.muted)
 button(U.workPanel,'save','Save route',504,0,100,30,'primary'); button(U.workPanel,'discard','Discard draft',612,0,98,30,'subtle')
 button(U.workPanel,'finishRecording','Finish trail',504,0,100,30,'primary',U.actions.record)
 button(U.workPanel,'saveRecording','Save recording',484,0,120,30,'primary'); button(U.workPanel,'discardRecording','Discard',612,0,98,30,'subtle')
 U.name=place(S.Edit(U.workPanel,320),U.workPanel,0,54,320,29); U.name:SetText('My farming trail')
 button(U.workPanel,'loop','Loop: on',340,54,142,29,'subtle'); button(U.workPanel,'reverse','Reverse direction',492,54,218,29,'subtle')
 button(U.workPanel,'resumeRecording','Resume recording',492,54,218,29,'gold')
 U.pointsPanel=place(S.Panel(U.workPanel),U.workPanel,0,98,252,244)
 U.pointCount=label(U.pointsPanel,'WAYPOINTS',12,9,228,17,10,S.dim); U.pointRows={}
 U.pointCount:SetWidth(112); button(U.pointsPanel,'workMap','Edit on map',132,6,108,23,'quiet',U.actions.map)
 for i=1,6 do
  local row=button(U.pointsPanel,'pointRow'..i,'',8,33+(i-1)*27,236,26,'quiet',function(self) if self.index then A.editIndex=self.index; U.Refresh() end end)
  row.label:SetJustifyH('LEFT'); U.pointRows[i]=row
 end
 button(U.pointsPanel,'pointPrev','< Previous',12,208,107,25,'quiet'); button(U.pointsPanel,'pointNext','Next >',129,208,111,25,'quiet')
 U.editorSketch=A.RouteSketch.New(U.workPanel); place(U.editorSketch.frame,U.workPanel,270,98,440,164)
 U.editorInfo=label(U.workPanel,'',284,274,412,21,12,S.text)
 button(U.workPanel,'pointUp','Earlier',284,303,101,27,'subtle'); button(U.workPanel,'pointDown','Later',395,303,101,27,'subtle'); button(U.workPanel,'deletePoint','Remove point',506,303,190,27,'subtle')
 U.workHint=label(U.workPanel,'',0,349,710,28,11,S.muted); U.workHint:SetWordWrap(true)
end
local function buildAtlas()
 U.atlasView=A.AtlasView.New(U.content,U);U.atlas=U.atlasView.frame
 U.atlasRows=U.atlasView.rows;U.atlasInfo=U.atlasView.info;U.atlasPageLabel=U.atlasView.pageLabel
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
local function buildNodeOptions()
 U.nodeOptions=place(CreateFrame('Frame',nil,U.content),U.content,20,19,710,395)
 label(U.nodeOptions,'Known node locations',0,0,710,26,18,S.gold,true)
 label(U.nodeOptions,'Gathering filters map markers. Materials filter route generation.',0,33,710,20,12,S.muted)
 local display=place(CreateFrame('Frame',nil,U.nodeOptions),U.nodeOptions,0,66,344,260)
 local tracking=place(CreateFrame('Frame',nil,U.nodeOptions),U.nodeOptions,360,66,350,260)
 label(display,'Marker appearance',16,14,310,23,17,S.gold,true)
 check(display,'nodeWorld','World map',14,46,110);check(display,'nodeMini','Minimap',176,46,120)
 label(display,'Minimap outline',16,85,124,26,13,S.text)
 dropdown(display,'nodeOutline',{{value='ring',label='Ring'},{value='square',label='Square'},{value='none',label='None (icon only)'}},154,85,172)
 check(display,'nodeIcon','Show minimap icons',14,124,260)
 S.Hint(U.controls.nodeIcon,'Minimap resource icons','World-map nodes always use icons. On the minimap, an icon stays enabled when there is no outline, so at least one marker layer remains visible.')
 label(display,'Outline size',16,163,126,26,13,S.text)
 dropdown(display,'nodeOutlineSize',choices({20,24,28,32,36,40},' px'),154,163,172,nil,function(v) return v..' px' end)
 label(display,'Icon size',16,202,126,26,13,S.text)
 dropdown(display,'nodeIconSize',choices({10,12,14,16,18,20,24},' px'),154,202,172,nil,function(v) return v..' px' end)
 label(tracking,'Minimap tracking',16,14,318,23,17,S.gold,true)
 label(tracking,'Hide icon within',16,46,160,26,13,S.text)
 local distances=choices({0,5,10,15,20,30,40,60,80,100},' yards');distances[1].label='Never'
 dropdown(tracking,'nodeDistance',distances,184,46,150,nil,function(v) return v==0 and 'Never' or (v..' yards') end)
 check(tracking,'nodeRouteLine','Show minimap route line',14,85,282)
 S.Hint(U.controls.nodeRouteLine,'Minimap route line','Thin lines leave gaps around known spawns. Hide them to remove route-line obstruction; the guide arrow and world-map route remain available.')
 local help=label(tracking,'World map uses icons only. Nearby minimap icons hide; outlines remain. Routes avoid known spawns.',16,124,316,44,12,S.muted); help:SetWordWrap(true)
 U.professionRanks=label(tracking,'',16,176,316,30,12,S.text); U.professionRanks:SetWordWrap(true)
 local sourceNote=label(tracking,'Colours use Classic reference data. Missing data stays neutral.',16,213,316,30,11,S.muted);sourceNote:SetWordWrap(true)
 button(tracking,'inspectNode','Inspect next node',16,246,200,24,'subtle',function() if A.DifficultyProbe and A.DifficultyProbe.Arm() then U.frame:Hide() end end)
 S.Hint(U.controls.inspectNode,'Inspect a native node','Capture the next herb or vein tooltip in the game world. Then use /gcf inspect report. Captures stay local and do not change difficulty colours.')
 for i,entry in ipairs({{'orange','Orange'},{'yellow','Yellow'},{'green','Green'},{'grey','Grey'},{'red','Too difficult'},{'unknown','Unknown'}}) do
  local x=(i-1)*118
  local swatch=S.Fill(U.nodeOptions,A.Resources.colors[entry[1]],'ARTWORK');place(swatch,U.nodeOptions,x,58,10,10)
  label(U.nodeOptions,entry[2],x+16,52,102,23,11,S.muted)
 end
 label(U.nodeOptions,'Marker opacity',16,310,310,20,13,S.gold)
 U.nodeOpacityLabels={}
 for i,entry in ipairs({{'nodeWorldOpacity','World-map icons'},{'nodeMiniIconOpacity','Minimap icons'},{'nodeOutlineOpacity','Minimap outlines'}}) do
  local key,title=entry[1],entry[2];local x=16+(i-1)*236
  U.nodeOpacityLabels[key]=label(U.nodeOptions,title,x,337,220,20,12,S.text)
  U.controls[key]=place(S.Slider(U.nodeOptions,0,100,5,U.actions[key],function(v) return v..'%' end),U.nodeOptions,x,365,188,12)
  S.Hint(U.controls[key],title..' opacity','Adjust Gather Compass node markers from 0% (transparent) to 100% (solid). Navigation markers and native tracking dots keep their own appearance.')
 end
end
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
 U.frame=CreateFrame('Frame','GatherCompassForeverWindow',UIParent);U.frame:Hide()
 U.compactBackground=S.Panel(U.frame);U.compactBackground:SetAllPoints()
 U.chrome=S.Window(U.frame);U.chrome:SetAllPoints();U.chrome:SetFrameLevel(U.frame:GetFrameLevel()); U.frame:SetPoint('CENTER',UIParent,'CENTER',0,0)
 U.frame:EnableMouse(true);U.frame:SetFrameStrata('DIALOG'); U.frame:SetClampedToScreen(true); U.frame:SetMovable(true); S.FitWindow(U.frame,W,H); buildHeader()
 U.body=place(CreateFrame('Frame',nil,U.frame),U.frame,12,100,936,414); buildSidebar()
 U.content=place(CreateFrame('Frame',nil,U.body),U.body,194,0,742,414)
 buildLibrary(); buildWork(); buildAtlas(); buildPreferences(); buildNodeOptions(); buildFooter()
 U.resourceLibraryView=A.ResourceLibraryView.New(U.content,U)
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
local function routeSummary(r)
 local nodes={}; for _,n in ipairs(A.db.nodes[r.mapID] or {}) do nodes[n.key]=n end
 local herbs,ore,unknown=0,0,false
 for _,p in ipairs(r.points) do if p.kind=='gather' then local n=p.nodeKey and nodes[p.nodeKey]; if not n then unknown=true elseif n.kind=='herb' then herbs=herbs+1 elseif n.kind=='ore' then ore=ore+1 end end end
 return #r.points,unknown and '?' or herbs,unknown and '?' or ore
end
local function refreshLibrary()
 local ids={}; for id in pairs(A.db.routes) do ids[#ids+1]=id end
 table.sort(ids,function(a,b) local x,y=A.db.routes[a].name,A.db.routes[b].name; if x==y then return a<b end; return x<y end)
 local pages=math.max(1,math.ceil(#ids/ROUTES_PER_PAGE)); U.routePage=math.max(1,math.min(U.routePage,pages))
 if not A.selectedRoute then A.selectedRoute=ids[(U.routePage-1)*ROUTES_PER_PAGE+1] end
 U.libraryInfo:SetText(#ids==0 and 'A new circuit starts with a discovery.' or (#ids..' saved '..(#ids==1 and 'route' or 'routes')..'  /  Select a trail to explore.'))
 for i,b in ipairs(U.cards) do
  local id=ids[(U.routePage-1)*ROUTES_PER_PAGE+i]; b.routeID=id; show(b,id~=nil)
  if id then local r=A.db.routes[id]; b:SetText(safe(r.name)); b.meta:SetText(#r.points..' waypoints   /   '..(r.loop and 'Loop' or 'One-way')); S.Selected(b,A.selectedRoute==id) end
 end
 U.routePageLabel:SetText(#ids>0 and (U.routePage..' / '..pages) or 'No saved routes'); U.controls.prevRoute:SetEnabled(U.routePage>1); U.controls.nextRoute:SetEnabled(U.routePage<pages)
 show(U.controls.prevRoute,#ids>0); show(U.controls.nextRoute,#ids>0); show(U.routePageLabel,#ids>0)
 local r=A.selectedRoute and A.db.routes[A.selectedRoute]; show(U.detail,r~=nil); show(U.empty,#ids==0)
 if r then
  U.previewName:SetText(safe(r.name)); U.routeType:SetText(r.loop and 'LOOP' or 'ONE-WAY'); U.previewMeta:SetText(safe(U.ZoneName(r.mapID))..'  /  '..(r.recorded and 'Recorded trail' or r.generated and 'Direct connections' or 'Custom waypoints'))
  local n,h,o=routeSummary(r); for i,v in ipairs({n,h,o}) do U.statValues[i]:SetText(v) end
 end
 U.routeSketch:Draw(r);U.controls.edit:SetEnabled(r~=nil);U.controls.deleteRoute:SetEnabled(r~=nil)
end
local function refreshWork()
 local recording=A.recording~=nil; local pending=A.recordedDraft~=nil; local editing=A.editor~=nil
 local r=A.editor and A.editor.draft or A.recordedDraft or A.recording and {mapID=A.recording.mapID,points=A.recording.points,loop=false}
 U.workTitle:SetText(editing and 'ROUTE EDITOR' or recording and 'RECORDING A TRAIL' or 'YOUR RECORDED TRAIL')
 U.workSubtitle:SetText(editing and 'Drag waypoints on the world map. Save or discard when finished.' or recording and 'Your travelled path, captured as waypoints.' or 'Give your trail a name, then save or discard it.')
 for _,key in ipairs({'save','discard','loop','reverse','pointUp','pointDown','deletePoint'}) do show(U.controls[key],editing) end
 show(U.controls.finishRecording,recording); show(U.controls.saveRecording,pending); show(U.controls.discardRecording,pending); show(U.controls.resumeRecording,recording and A.recording.paused)
 U.controls.saveRecording:SetEnabled(pending); U.controls.discardRecording:SetEnabled(pending)
 if not r then return end
 local points=r.points; A.editIndex=math.max(1,math.min(A.editIndex or 1,math.max(1,#points))); local page=math.floor((A.editIndex-1)/6)
 U.pointCount:SetText(#points..' WAYPOINTS'..(recording and ' CAPTURED' or ''))
 for i,row in ipairs(U.pointRows) do
  local index=page*6+i; local p=points[index]; row.index=p and index or nil; show(row,p~=nil)
  if p then row:SetText(string.format('%03d   %s',index,p.kind=='gather' and 'Gathering stop' or 'Travel waypoint')); S.Selected(row,index==A.editIndex); row:SetEnabled(not recording) end
 end
 U.controls.pointPrev:SetEnabled(A.editIndex>1); U.controls.pointNext:SetEnabled(A.editIndex<#points)
 U.controls.pointUp:SetEnabled(A.editIndex>1); U.controls.pointDown:SetEnabled(A.editIndex<#points); U.controls.deletePoint:SetEnabled(#points>0)
 U.editorSketch:Draw(r,A.editIndex)
 local p=points[A.editIndex]; U.editorInfo:SetText(p and string.format('Waypoint %d   /   %.1f, %.1f',A.editIndex,p.x*100,p.y*100) or 'Open the world map and click to add waypoints.')
 U.controls.loop:SetText(r.loop and 'Loop: on' or 'Loop: off'); S.Selected(U.controls.loop,r.loop)
 U.workHint:SetText(recording and (A.recording.reason or 'Recording your movement. Finish the trail when you are ready.') or pending and 'Recorded paths can be edited after saving. No terrain avoidance is assumed.' or 'Click the world map to add points; drag markers to move. Add detours through bridges, passes and cave entrances.')
end
local function refreshAtlas() U.atlasView.Refresh() end
local function refreshFooter(p)
 local f=A.follower; local active=f and (f.status=='running' or f.status=='paused' or f.status=='suspended'); local work=A.editor or A.recording or A.recordedDraft
 local r=f and f.route or A.selectedRoute and A.db.routes[A.selectedRoute]; U.footerName:SetText(safe(r and r.name or 'Ready for your first discovery'))
 local detail='Select a route, or create a new trail.'
 if A.editor then U.footerName:SetText('Route draft'); detail=#A.editor.draft.points..' waypoints / Not saved'
 elseif A.recording then U.footerName:SetText('Recording your path'); detail='Recording / '..#A.recording.points..' waypoints'..(A.recording.paused and ' / Paused' or '')
 elseif A.recordedDraft then U.footerName:SetText('Your trail is ready to save'); detail=#A.recordedDraft.points..' waypoints / Awaiting save'
 elseif f then detail=(f.status=='complete' and 'Complete' or f.status=='paused' and 'Paused by you' or f.status=='suspended' and 'Guidance suspended' or 'Following route')..' / '..f.index..' of '..#f.route.points..(f.route.loop and (' / Lap '..(f.lap+1)) or '')
 elseif r then detail='Ready to follow / Join near your current position' end
 U.footerMeta:SetText(detail)
 show(U.controls.start,not active and not work); show(U.controls.pause,active and not work); show(U.controls.skip,active and not work); show(U.controls.stop,active and not work)
 show(U.controls.followReverse,active and not work and not U.compact); show(U.controls.expand,U.compact); show(U.controls.workReturn,work and (U.tab~='routes' or U.compact))
 U.controls.pause:SetText(f and f.status=='paused' and 'Resume' or 'Pause')
 local selected=A.selectedRoute and A.db.routes[A.selectedRoute]
 U.controls.start:SetEnabled(selected~=nil and p~=nil and selected.mapID==p.mapID and A.Client.Distance(p,selected.points[1])~=nil)
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
 local resource=U.tab=='resources';local nodes=resource and {} or U.SelectedNodes()
 show(U.sidebar,not resource);place(U.content,U.body,resource and 0 or 194,0,resource and 936 or 742,414)
 U.RefreshMode(); for id,b in pairs(U.tabs) do S.Selected(b,id==U.tab) end
 show(U.library,U.tab=='routes' and not work); show(U.workPanel,U.tab=='routes' and work~=nil); show(U.atlas,U.tab=='atlas'); show(U.preferences,U.tab=='settings'); show(U.nodeOptions,U.tab=='nodes')
 show(U.resourceLibraryView.frame,resource)
 if not resource then refreshSidebar(p) end
 if U.tab=='routes' then if work then refreshWork() else refreshLibrary() end elseif U.tab=='atlas' then refreshAtlas() elseif resource then U.resourceLibraryView.Refresh() end
 refreshFooter(p); refreshStatus(p); U.controls.generate:SetEnabled(#nodes>0)
 local marker=A.Resources.Settings(A.db.settings)
 U.controls.nodeWorld:SetChecked(marker.world);U.controls.nodeMini:SetChecked(marker.mini)
 U.controls.nodeRouteLine:SetChecked(marker.routeLines)
 U.controls.nodeOutline:SetValue(marker.outline)
 U.controls.nodeIcon:SetEnabled(marker.outline~='none');U.controls.nodeIcon:SetChecked(marker.icon)
 U.controls.nodeOutlineSize:SetValue(marker.outlineSize);U.controls.nodeIconSize:SetValue(marker.iconSize)
 U.controls.nodeDistance:SetValue(marker.hideDistance)
 U.syncingOptions=true
 for _,entry in ipairs({{'nodeWorldOpacity','worldIconOpacity','World-map icons'},{'nodeMiniIconOpacity','miniIconOpacity','Minimap icons'},{'nodeOutlineOpacity','miniOutlineOpacity','Minimap outlines'}}) do
  local value=math.floor(marker[entry[2]]*100+.5)
  U.controls[entry[1]]:SetValue(value);U.nodeOpacityLabels[entry[1]]:SetText(entry[3]..': '..value..'%')
 end
 U.syncingOptions=false
 if U.tab=='nodes' then
  local ranks=A.Resources.Skills()
  U.professionRanks:SetText('Base Herbalism: '..(ranks.herb or 'unavailable')..'\nBase Mining: '..(ranks.ore or 'unavailable'))
 end
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
