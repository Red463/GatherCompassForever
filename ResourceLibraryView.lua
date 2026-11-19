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
 local view={kind='all',search='',page=1,zonePage=1,mode='grid',tiles={},sourceRows={},zoneRows={}}
 local root=place(CreateFrame('Frame',nil,parent),parent,20,19,896,377);view.frame=root
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
 function view.ShowZone(mapID)
  if work() then message('Save or discard the current draft or recording before opening a resource map.');return end
  local item=view.item;local valid=false
  if item then for _,zone in ipairs(item.zones) do if zone.mapID==mapID then valid=true;break end end end
  if not valid or not WorldMapFrame or not A.Map or not A.Map.SetNodeFocus then message('Select a zone with known locations first.');return end
  local ok,reason=A.Map.SetNodeFocus(mapID,item.materialIDs,nil,'combined')
  if not ok then message(reason or 'World-map resource focus is unavailable.');return end
  WorldMapFrame:Show();if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
  A.Map.Refresh(A.db,U.DisplayRoute(),A.follower);U.frame:Hide()
  A.status='World map: '..item.name..' in '..U.ZoneName(mapID)..'. Close the map to restore its normal display.'
 end
 local grid=place(CreateFrame('Frame',nil,root),root,0,0,896,377);view.grid=grid
 label(grid,'Resources',0,0,180,26,18,S.gold)
 view.info=label(grid,'',0,34,896,18,12,S.muted)
 local kind=place(S.Dropdown(grid,{{value='all',label='All resources'},{value='herb',label='Herbs'},{value='ore',label='Ore'}},function(value) view.kind=value;view.page=1;U.Refresh() end),grid,190,1,166,26);U.controls.resourceType=kind
 label(grid,'Search',370,3,48,24,12,S.gold)
 view.searchBox=place(S.Edit(grid,224),grid,422,1,224,26);U.controls.resourceSearch=view.searchBox
 view.searchBox:SetScript('OnTextChanged',function(self) view.SetSearch(self:GetText()) end)
 button(grid,'resourceClear','Clear',654,1,70,26,function() view.SetSearch('') end)
 button(grid,'resourceImport','Import node data',734,1,162,26,function() if A.Import then A.Import() else message('Import is unavailable.');end end)
 for i=1,27 do
  local cell=place(S.Panel(grid),grid,((i-1)%9)*100,66+math.floor((i-1)/9)*98,88,88)
  local b=S.Button(cell,'',function(self) if self.item then view.Open(self.item.id) end end,'quiet');b:SetAllPoints(cell);b.cell=cell
  b.icon=b:CreateTexture(nil,'ARTWORK');place(b.icon,b,22,7,44,44)
  b.label:ClearAllPoints();place(b.label,b,4,53,80,31);b.label:SetJustifyH('CENTER');b.label:SetFont(S.bodyFont,11,'');b.label:SetWordWrap(true)
  S.Hint(b,'Resource information',function()
   local item=b.item;if not item then return '' end
   return safe(item.name)..'\n'..(item.kind=='herb' and 'Herbalism' or 'Mining')..'\n'..item.count..' known locations in '..#item.zones..' zones.\nClick for gathering sources, skills and ranked zones.'
  end)
  view.tiles[i]=b
 end
 view.empty=label(grid,'No resources match. Clear the search or choose another type.',190,150,516,90,15,S.muted);view.empty:SetWordWrap(true);view.empty:SetJustifyH('CENTER')
 button(grid,'resourcePrev','< Previous',0,354,106,23,function() view.page=math.max(1,view.page-1);U.Refresh() end,'quiet')
 button(grid,'resourceNext','Next >',790,354,106,23,function() view.page=view.page+1;U.Refresh() end,'quiet')
 view.pageLabel=label(grid,'',120,355,656,22,11,S.muted);view.pageLabel:SetJustifyH('CENTER')
 local detail=place(CreateFrame('Frame',nil,root),root,0,0,896,377);view.detail=detail
 button(detail,'resourceBack','< Back to resources',0,5,158,26,view.Back)
 view.icon=detail:CreateTexture(nil,'ARTWORK');place(view.icon,detail,176,0,44,44)
 view.name=label(detail,'',234,0,662,25,20,S.gold)
 view.profession=label(detail,'',234,29,662,18,12,S.muted)
 local information=place(S.Panel(detail),detail,0,64,330,313)
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
  S.Hint(row,'Gathering source',function()
   local d=row.details;if not d then return '' end
   return safe(row.node.name)..'\n'..d.requirement..'\n'..d.summary..(d.transition and ('\n'..d.transition) or '')..(d.contextNote and ('\n'..d.contextNote) or '')..'\n'..(d.source=='reference' and 'Source: Reference data (Classic)' or 'Source: Unknown')
  end)
  view.sourceRows[i]=row
 end
 local zones=place(S.Panel(detail),detail,344,64,552,313)
 label(zones,'Where to gather',14,12,524,23,17,S.gold)
 label(zones,'Ranked by known locations. Possible spawns, not live availability.',14,43,524,18,11,S.muted)
 label(zones,'Zone',16,77,310,18,12,S.gold)
 local totals=label(zones,'Known / Personal',360,77,176,18,12,S.gold);totals:SetJustifyH('RIGHT')
 for i=1,7 do
  local row=button(zones,'resourceZone'..i,'',12,103+(i-1)*25,528,24,function(self) if self.zone then view.ShowZone(self.zone.mapID) end end,'quiet')
  row.label:ClearAllPoints();place(row.label,row,4,0,338,24);row.label:SetJustifyH('LEFT')
  row.counts=label(row,'',348,0,174,24,11,S.muted);row.counts:SetJustifyH('RIGHT')
  S.Hint(row,'Show resource locations',function()
   if not row.zone then return '' end
   return safe(U.ZoneName(row.zone.mapID))..'\n'..row.zone.count..' known locations / '..row.zone.confirmed..' personally confirmed.\nClick to show this resource on the world map.\nSave or discard unfinished work first.'
  end)
  view.zoneRows[i]=row
 end
 view.zoneEmpty=label(zones,'No known locations yet. Import node data or gather this resource to record locations.',52,118,448,120,14,S.muted);view.zoneEmpty:SetWordWrap(true);view.zoneEmpty:SetJustifyH('CENTER')
 button(zones,'resourceZonePrev','<',12,284,26,23,function() view.zonePage=math.max(1,view.zonePage-1);U.Refresh() end,'quiet')
 button(zones,'resourceZoneNext','>',514,284,26,23,function() view.zonePage=view.zonePage+1;U.Refresh() end,'quiet')
 view.zonePageLabel=label(zones,'',48,285,456,22,11,S.muted);view.zonePageLabel:SetJustifyH('CENTER')
 function view.Refresh()
  local model=A.ResourceLibrary.Query(A.db,view.mode=='detail' and 'all' or view.kind,view.mode=='detail' and '' or view.search)
  view.model=model;view.item=nil
  for _,item in ipairs(model.items) do if item.id==view.selectedID then view.item=item;break end end
  if view.mode=='detail' and not view.item then view.mode='grid';view.Refresh();return end
  show(grid,view.mode=='grid');show(detail,view.mode=='detail');kind:SetValue(view.kind)
  U.zone:SetText('Resource library  -  All imported and personal locations')
  if view.mode=='grid' then
   local pages=math.max(1,math.ceil(#model.items/27));view.page=math.max(1,math.min(view.page,pages))
   view.info:SetText(#model.items..' resources / Choose an item for skill guidance and ranked zones')
   for i,tile in ipairs(view.tiles) do
    local item=model.items[(view.page-1)*27+i];tile.item=item;show(tile.cell,item~=nil)
    if item then tile:SetText(safe(item.name));tile.icon:SetTexture(item.icon);S.Selected(tile,item.id==view.selectedID) end
   end
   show(view.empty,#model.items==0);view.pageLabel:SetText('Page '..view.page..' / '..pages)
   U.controls.resourcePrev:SetEnabled(view.page>1);U.controls.resourceNext:SetEnabled(view.page<pages)
   return
  end
  local item=view.item;view.icon:SetTexture(item.icon);view.name:SetText(safe(item.name))
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
    row:SetEnabled(not work() and WorldMapFrame~=nil and A.Map~=nil and A.Map.SetNodeFocus~=nil)
   end
  end
  show(view.zoneEmpty,#item.zones==0);view.zonePageLabel:SetText('Zones '..view.zonePage..' / '..pages..' / Click a zone to show its map')
  U.controls.resourceZonePrev:SetEnabled(view.zonePage>1);U.controls.resourceZoneNext:SetEnabled(view.zonePage<pages)
 end
 return view
end
