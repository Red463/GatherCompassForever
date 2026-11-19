local _,A=...
local S=A.Skin
local V={};A.ResourceLibraryView=V
local function safe(text) return tostring(text or ''):gsub('|','||') end
local function place(frame,parent,x,y,w,h) frame:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);frame:SetSize(w,h);return frame end
local function show(frame,on) if on then frame:Show() else frame:Hide() end end
local function label(parent,text,x,y,w,h,size,color)
 return place(S.Label(parent,text,size or 12,color or S.text),parent,x,y,w,h)
end
local function lastGathered(value)
 if A.Store.Number(value) and value>0 then
  if type(date)=='function' then local ok,text=pcall(date,'%d %b %Y %H:%M',value);if ok and type(text)=='string' then return text end end
  return 'Recorded (date unavailable)'
 end
 return 'Not recorded'
end
local function work() return A.editor or A.recording or A.recordedDraft end
function V.New(parent,U)
 local view={kind='all',scope='all',source='combined',skill='all',search='',page=1,zonePage=1,mode='grid',tiles={},sourceRows={},zoneRows={}}
 local root=place(CreateFrame('Frame',nil,parent),parent,20,19,896,395);view.frame=root
 local function button(parent,key,text,x,y,w,h,fn,style)
  local b=place(S.Button(parent,text,fn,style),parent,x,y,w,h or 24);U.controls[key]=b;return b
 end
 local function message(text) A.status=text;U.Refresh() end
 function view.SetSearch(text)
  text=tostring(text or '')
  if view.search==text then return end
  view.search=text;view.page=1
  if view.searchBox:GetText()~=text then view.searchBox:SetText(text) end
  U.Refresh()
 end
 function view.Open(id) view.selectedID=id;view.mode='detail';view.zonePage=1;S.CloseDropdown();U.Refresh() end
 function view.Back() view.mode='grid';U.Refresh() end
 local function mapAvailable(item,mapID)
  local filter=U.Filter();local signature=A.FarmingSession.Signature(filter)..'/'..view.source
  if view.mapNodes~=item.nodes or view.mapSignature~=signature then
   view.mapNodes=item.nodes;view.mapSignature=signature;view.mapZones={}
   local focus={source=view.source,materials=item.materialIDs}
   for _,n in ipairs(item.nodes) do if A.Selection.Matches(n,filter) and A.Selection.Matches(n,focus) then view.mapZones[n.mapID]=true end end
  end
  return view.mapZones[mapID]==true
 end
 function view.ShowZone(mapID)
  if work() then message('Save or discard the current draft or recording before opening a resource map.');return end
  local item=view.item;local valid=false
  if item then for _,zone in ipairs(item.zones) do if zone.mapID==mapID then valid=true;break end end end
  if not valid or not WorldMapFrame or not A.Map or not A.Map.SetNodeFocus then message('Select a zone with known locations first.');return end
  if not mapAvailable(item,mapID) then message('Select this resource and its source in Routes to show matching map locations.');return end
  local ok,reason=A.Map.SetNodeFocus(mapID,item.materialIDs,nil,view.source)
  if not ok then message(reason or 'World-map resource focus is unavailable.');return end
  WorldMapFrame:Show();if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
  A.Map.Refresh(A.db,U.DisplayRoute(),A.follower);U.frame:Hide()
  A.status='World map: '..item.name..' in '..U.ZoneName(mapID)..'. Close the map to restore its normal display.'
 end
 local grid=place(CreateFrame('Frame',nil,root),root,0,0,896,395);view.grid=grid
 label(grid,'Node Codex',0,0,180,26,18,S.gold)
 view.info=label(grid,'',0,73,896,18,12,S.muted)
 local kind=place(S.Dropdown(grid,{{value='all',label='All resources'},{value='herb',label='Herbs'},{value='ore',label='Ore'}},function(value) view.kind=value;view.page=1;U.Refresh() end),grid,0,37,190,26);U.controls.resourceType=kind
 label(grid,'Search',384,3,48,24,12,S.gold)
 view.searchBox=place(S.Edit(grid,224),grid,438,1,330,26);U.controls.resourceSearch=view.searchBox
 view.searchBox:SetScript('OnTextChanged',function(self) view.SetSearch(self:GetText()) end)
 button(grid,'resourceClear','Clear',778,1,118,26,function() view.SetSearch('') end)
 local function browse(key,items,x,w,field)
  local d=place(S.Dropdown(grid,items,function(value) view[field]=value;view.page=1;U.Refresh() end),grid,x,37,w,26);U.controls[key]=d;return d
 end
 local skill=browse('codexSkill',{{value='all',label='All skill levels'},{value='gatherable',label='Gatherable'},{value='skillups',label='Skill-ups'}},200,210,'skill')
 local scope=browse('codexScope',{{value='all',label='All zones'},{value='current',label='Current zone'}},420,210,'scope')
 local source=browse('codexSource',{{value='combined',label='All known sources'},{value='confirmed',label='My discoveries'},{value='imported',label='Imported locations'}},640,256,'source')
 for i=1,27 do
  local cell=place(S.Panel(grid),grid,((i-1)%9)*100,100+math.floor((i-1)/9)*90,88,88)
  local b=S.Button(cell,'',function(self) if self.item then view.Open(self.item.id) end end,'quiet');b:SetAllPoints(cell);b.cell=cell
  b.icon=b:CreateTexture(nil,'ARTWORK');place(b.icon,b,22,7,44,44)
  b.label:ClearAllPoints();place(b.label,b,4,53,80,31);b.label:SetJustifyH('CENTER');b.label:SetFont(S.bodyFont,11,'');b.label:SetWordWrap(true)
  A.SkillTooltip.Bind(b,'Resource information',function()
   local entries={};if b.item then for _,row in ipairs(b.item.skillSources or b.item.sources) do entries[#entries+1]={node=row.node} end end;return entries
  end,function()
   local item=b.item;if not item then return '' end
   return item.count..' known locations in '..#item.zones..' zones. Click for sources, history and ranked zones.'
  end)
  b.skillBar=b:CreateTexture(nil,'OVERLAY');place(b.skillBar,b,3,83,82,3)
  view.tiles[i]=b
 end
 view.empty=label(grid,'No resources match. Clear the search or choose another type.',190,150,516,90,15,S.muted);view.empty:SetWordWrap(true);view.empty:SetJustifyH('CENTER')
 button(grid,'resourcePrev','< Previous',0,372,106,23,function() view.page=math.max(1,view.page-1);U.Refresh() end,'quiet')
 button(grid,'resourceNext','Next >',790,372,106,23,function() view.page=view.page+1;U.Refresh() end,'quiet')
 view.pageLabel=label(grid,'',120,373,656,22,11,S.muted);view.pageLabel:SetJustifyH('CENTER')
 local detail=place(CreateFrame('Frame',nil,root),root,0,0,896,395);view.detail=detail
 button(detail,'resourceBack','< Back to Codex',0,5,158,26,view.Back)
 view.icon=detail:CreateTexture(nil,'ARTWORK');place(view.icon,detail,176,0,44,44)
 view.name=label(detail,'',234,0,662,25,20,S.gold)
 view.profession=label(detail,'',234,29,662,18,12,S.muted)
 local information=place(S.Panel(detail),detail,0,64,330,296)
 view.stats=label(information,'',14,12,302,48,12,S.text);view.stats:SetWordWrap(true)
 view.last=label(information,'',14,66,302,18,11,S.muted)
 label(information,'Gathering sources',14,91,302,22,15,S.gold)
 for i=1,2 do
  local row=place(CreateFrame('Frame',nil,information),information,14,120+(i-1)*88,302,80)
  row.name=label(row,'',0,0,302,17,12,S.gold)
  row.requirement=label(row,'',0,20,302,17,11,S.text)
  row.summary=label(row,'',0,39,302,17,11,S.text)
  row.transition=label(row,'',0,58,302,17,11,S.muted)
  row:EnableMouse(true)
  A.SkillTooltip.Bind(row,'Gathering source',function() return row.node and {{node=row.node,details=row.details}} or {} end)
  view.sourceRows[i]=row
 end
 local zones=place(S.Panel(detail),detail,344,64,552,296)
 label(zones,'Where to gather',14,12,524,23,17,S.gold)
 label(zones,'Ranked by known locations. Possible spawns, not live availability.',14,43,524,18,11,S.muted)
 label(zones,'Zone',16,68,310,18,12,S.gold)
 local totals=label(zones,'Known / Personal',360,68,176,18,12,S.gold);totals:SetJustifyH('RIGHT')
 for i=1,7 do
  local row=button(zones,'resourceZone'..i,'',12,90+(i-1)*24,528,23,function(self) if self.zone then view.ShowZone(self.zone.mapID) end end,'quiet')
  row.label:ClearAllPoints();place(row.label,row,4,0,338,24);row.label:SetJustifyH('LEFT')
  row.counts=label(row,'',348,0,174,24,11,S.muted);row.counts:SetJustifyH('RIGHT')
  S.Hint(row,'Show resource locations',function()
   if not row.zone then return '' end
   return safe(U.ZoneName(row.zone.mapID))..'\n'..row.zone.count..' known locations / '..row.zone.confirmed..' personally confirmed.\nClick to show this resource on the world map.\nSave or discard unfinished work first.'
  end)
  view.zoneRows[i]=row
 end
 view.zoneEmpty=label(zones,'No known locations yet. Import data on Welcome or gather this resource to record locations.',52,118,448,120,14,S.muted);view.zoneEmpty:SetWordWrap(true);view.zoneEmpty:SetJustifyH('CENTER')
 button(zones,'resourceZonePrev','<',12,270,26,23,function() view.zonePage=math.max(1,view.zonePage-1);U.Refresh() end,'quiet')
 button(zones,'resourceZoneNext','>',514,270,26,23,function() view.zonePage=view.zonePage+1;U.Refresh() end,'quiet')
 view.zonePageLabel=label(zones,'',48,271,456,22,11,S.muted);view.zonePageLabel:SetJustifyH('CENTER')
 view.localInfo=label(detail,'',0,45,896,18,11,S.muted)
 local function current()
  local player=A.Client.Position();return A.ResourceLibrary.LocalCandidates(A.db,view.item,player,U.Filter()),player
 end
 local function blocked()
  if work() then message('Finish the current work before starting guidance.');return true end
  local f=A.follower;if f and (f.status=='running' or f.status=='paused' or f.status=='suspended') then message('Stop current guidance before starting another resource.');return true end
 end
 function view.Plan()
  if blocked() then return end
  local nodes,player=current();if #nodes==0 then message('Select this resource in Routes and enter a zone with matching known locations.');return end
  U.ReviewNodes(nodes,player)
 end
 function view.Guide()
  if blocked() then return end
  local nodes,player=current();local nearest,best
  for _,n in ipairs(nodes) do local d=A.Client.Distance(player,n);if A.Store.Number(d) and (not best or d<best) then nearest,best=n,d end end
  if not nearest then message('Select this resource in Routes with readable current-zone locations.');return end
  local target={mapID=nearest.mapID,x=nearest.x,y=nearest.y,kind='gather',nodeKey=nearest.key,name=nearest.name or view.item.name}
  if A.plan then A.plan.review=false end
  A.follower=A.Follower.New({name='Nearest '..view.item.name,mapID=nearest.mapID,points={target},loop=false},player,A.Client.Distance,{arrival=A.db.settings.arrival})
  A.mapPreviewRoute=nil;if A.Map and A.Map.SetNodeFocus then A.Map.SetNodeFocus(nil);A.Map.Refresh(A.db,U.DisplayRoute(),A.follower) end
  U.frame:Hide();message('Guiding to a known '..view.item.name..' location.')
 end
 button(detail,'codexPlan','Review resource route',0,369,206,26,view.Plan)
 button(detail,'codexGuide','Guide nearest',216,369,150,26,view.Guide)
 button(detail,'codexMap','Show current zone',376,369,206,26,function() local p=A.Client.Position();if p then view.ShowZone(p.mapID) end end)
 S.Hint(U.controls.codexPlan,'Resource route','Uses this resource and your Routes checkboxes. Stop current guidance first.')
 S.Hint(U.controls.codexGuide,'Nearest known location','Uses your Routes checkboxes. Known locations are possible spawns, not live nodes.')
 function view.Refresh()
  local detailMode=view.mode=='detail';local p=A.Client.Position()
  local options=not detailMode and {scope=view.scope,source=view.source,skill=view.skill,mapID=p and p.mapID} or {source=view.source}
  local model=A.ResourceLibrary.Query(A.db,detailMode and 'all' or view.kind,detailMode and '' or view.search,options)
  view.model=model;view.item=nil
  for _,item in ipairs(model.items) do if item.id==view.selectedID then view.item=item;break end end
  if view.mode=='detail' and not view.item then view.mode='grid';view.Refresh();return end
  show(grid,view.mode=='grid');show(detail,view.mode=='detail');kind:SetValue(view.kind);skill:SetValue(view.skill);scope:SetValue(view.scope);source:SetValue(view.source)
  U.zone:SetText('Node Codex  -  Browse resources; choose farming materials in Routes')
  if view.mode=='grid' then
   local pages=math.max(1,math.ceil(#model.items/27));view.page=math.max(1,math.min(view.page,pages))
   view.info:SetText(#model.items..' resources / Browsing filters leave your Routes checkboxes unchanged')
   for i,tile in ipairs(view.tiles) do
    local item=model.items[(view.page-1)*27+i];tile.item=item;show(tile.cell,item~=nil)
    if item then tile.labelColor=item.skill.color;tile.skillBar:SetColorTexture(unpack(item.skill.color));tile:SetText(safe(item.name));tile.icon:SetTexture(item.icon);S.Selected(tile,item.id==view.selectedID) end
   end
   view.empty:SetText(view.scope=='current' and not p and 'Position unavailable. Choose All zones to browse the catalogue.' or 'No resources match. Clear the search or choose another filter.')
   show(view.empty,#model.items==0);view.pageLabel:SetText('Page '..view.page..' / '..pages)
   U.controls.resourcePrev:SetEnabled(view.page>1);U.controls.resourceNext:SetEnabled(view.page<pages)
   return
  end
  local item=view.item;view.icon:SetTexture(item.icon);view.name:SetText(safe(item.name))
  local nodes,player=current();local best
  for _,n in ipairs(nodes) do local d=A.Client.Distance(player,n);if A.Store.Number(d) and (not best or d<best) then best=d end end
  local f=A.follower;local active=f and (f.status=='running' or f.status=='paused' or f.status=='suspended')
  local can=#nodes>0 and best~=nil and not active and not work()
  U.controls.codexPlan:SetEnabled(can);U.controls.codexGuide:SetEnabled(can)
  local zoneAvailable=false;for _,z in ipairs(item.zones) do if player and z.mapID==player.mapID then zoneAvailable=true end end
  U.controls.codexMap:SetEnabled(zoneAvailable and player and mapAvailable(item,player.mapID) and not work())
  view.localInfo:SetText(not player and 'Position unavailable. Return to a gathering zone to plan or guide.' or #nodes..' current-zone locations matching Routes'..(best and string.format(' / Nearest known: %.0f yd',best) or ' / Select this resource in Routes to guide')..(active and ' / Stop current guidance first' or ''))

  view.profession:SetText((item.kind=='herb' and 'Herbalism' or 'Mining')..' / '..#item.sources..(#item.sources==1 and ' gathering source' or ' gathering sources'))
  view.stats:SetText(item.count..' known locations / '..#item.zones..' zones\n'..item.confirmed..' personal / '..item.imported..' imported locations\n'..item.harvests..' personal gathers')
  view.last:SetText('Last gathered: '..lastGathered(item.lastGathered))
  local skills,context=A.Resources.Skills()
  for i,row in ipairs(view.sourceRows) do
   local source=item.sources[i];show(row,source~=nil)
   if source then
    local d=A.Resources.SkillDetails(source.node,skills,context);row.node=source.node;row.details=d
    row.name:SetText(safe(source.node.name));row.requirement:SetText(safe(d.requirement));row.summary:SetText(safe(d.summary));row.summary:SetTextColor(unpack(d.color))
    row.transition:SetText(safe(d.transition or (d.source=='reference' and 'Source: Reference data (Classic)' or 'Source: Unknown')))
   else row.node=nil;row.details=nil end
  end
  local pages=math.max(1,math.ceil(#item.zones/7));view.zonePage=math.max(1,math.min(view.zonePage,pages))
  for i,row in ipairs(view.zoneRows) do
   local index=(view.zonePage-1)*7+i;local zone=item.zones[index];row.zone=zone;show(row,zone~=nil)
   if zone then
    row:SetText(safe(index..'. '..U.ZoneName(zone.mapID)));row.counts:SetText(zone.count..' / '..zone.confirmed)
    local matches=mapAvailable(item,zone.mapID)
    row:SetEnabled(matches and not work() and WorldMapFrame~=nil and A.Map~=nil and A.Map.SetNodeFocus~=nil)
   end
  end
  show(view.zoneEmpty,#item.zones==0);view.zonePageLabel:SetText('Zones '..view.zonePage..' / '..pages..' / Click a zone to show its map')
  U.controls.resourceZonePrev:SetEnabled(view.zonePage>1);U.controls.resourceZoneNext:SetEnabled(view.zonePage<pages)
 end
 return view
end
