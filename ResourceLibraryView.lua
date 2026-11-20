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
 local view={kind='all',scope='all',source='combined',skill='all',search='',mode='grid',tiles={},sourceRows={},zoneRows={}}
 local root=place(CreateFrame('Frame',nil,parent),parent,20,19,896,395);view.frame=root
 local function button(parent,key,text,x,y,w,h,fn,style)
  local b=place(S.Button(parent,text,fn,style),parent,x,y,w,h or 24);U.controls[key]=b;return b
 end
 local function message(text) A.status=text;U.Refresh() end
 function view.SetSearch(text)
  text=tostring(text or '')
  if view.search==text then return end
  view.search=text
  if view.searchBox:GetText()~=text then view.searchBox:SetText(text) end
  U.Refresh()
 end
 function view.Open(id) view.selectedID=id;view.mode='detail';S.CloseDropdown();U.Refresh() end
 function view.Back() view.mode='grid';U.Refresh() end
 local function mapAvailable(item,mapID)
  if A.Resources.Settings(A.db.settings).worldIconOpacity<=0 then return false,'World-map icon opacity is 0%. Increase World-map icons in Node display > World map to show these locations.' end
  local filter,override=U.MarkerFilter();local signature=A.FarmingSession.Signature(filter)..'/'..view.source
  if view.mapNodes~=item.nodes or view.mapSignature~=signature then
   view.mapNodes=item.nodes;view.mapSignature=signature;view.mapZones={}
   local focus={source=view.source,materials=item.materialIDs}
   for _,n in ipairs(item.nodes) do if A.Selection.Matches(n,filter) and A.Selection.Matches(n,focus) then view.mapZones[n.mapID]=true end end
  end
  if view.mapZones[mapID] then return true end
  return false,override and 'Active route override controls these markers. Stop guidance or turn off Use route selections while following to use everyday choices.' or 'Select this resource in Node display > Visible nodes to show matching map locations.'
 end
 function view.ShowZone(mapID)
  if work() then message('Save or discard the current draft or recording before opening a resource map.');return end
  local item=view.item;local valid=false
  if item then for _,zone in ipairs(item.zones) do if zone.mapID==mapID then valid=true;break end end end
  if not valid or not WorldMapFrame or not A.Map or not A.Map.SetNodeFocus then message('Select a zone with known locations first.');return end
  local available,reason=mapAvailable(item,mapID);if not available then message(reason);return end
  local ok,reason=A.Map.SetNodeFocus(mapID,item.materialIDs,nil,view.source)
  if not ok then message(reason or 'World-map resource focus is unavailable.');return end
  WorldMapFrame:Show();if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
  A.Map.Refresh(A.db,U.DisplayRoute(),A.follower);U.frame:Hide()
  A.status='World map: '..item.name..' in '..U.ZoneName(mapID)..'. Close the map to restore its normal display.'
 end
 local grid=place(CreateFrame('Frame',nil,root),root,0,0,896,395);view.grid=grid
 label(grid,'Node Codex',0,0,180,26,18,S.gold)
 view.info=label(grid,'',0,73,896,18,12,S.muted)
 local kind=place(S.Dropdown(grid,{{value='all',label='All resources'},{value='herb',label='Herbs'},{value='ore',label='Ore'}},function(value) view.kind=value;U.Refresh() end),grid,0,37,190,26);U.controls.resourceType=kind
 view.searchLabel=label(grid,'Search',384,3,48,24,12,S.gold)
 view.searchBox=place(S.Edit(grid,224),grid,438,1,330,26);U.controls.resourceSearch=view.searchBox
 view.searchBox:SetScript('OnTextChanged',function(self) view.SetSearch(self:GetText()) end)
 button(grid,'resourceClear','Clear',778,1,118,26,function() view.SetSearch('') end)
 local function browse(key,items,x,w,field)
  local d=place(S.Dropdown(grid,items,function(value) view[field]=value;U.Refresh() end),grid,x,37,w,26);U.controls[key]=d;return d
 end
 local skill=browse('codexSkill',{{value='all',label='All skill levels'},{value='gatherable',label='Gatherable'},{value='skillups',label='Skill-ups'}},200,210,'skill')
 local scope=browse('codexScope',{{value='all',label='All zones'},{value='current',label='Current zone'}},420,210,'scope')
 local source=browse('codexSource',{{value='combined',label='All known sources'},{value='confirmed',label='My discoveries'},{value='imported',label='Imported locations'}},640,256,'source')
 view.gridList=A.VirtualList.New(grid,{rowHeight=96,create=function(parent)
  local wrapper=CreateFrame('Frame',nil,parent)
  local cell=place(S.Panel(wrapper),wrapper,0,0,88,88)
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
  wrapper.button=b;view.tiles[#view.tiles+1]=b
  b:EnableMouseWheel(true);b:SetScript('OnMouseWheel',function(_,delta) view.gridList:SetOffset(view.gridList.scroller.offset-delta*96) end)
  return wrapper
 end,bind=function(wrapper,item)
  local b=wrapper.button;b.item=item;show(b.cell,item~=nil)
  if item then b.labelColor=item.skill.color;b.skillBar:SetColorTexture(unpack(item.skill.color));b:SetText(safe(item.name));b.icon:SetTexture(item.icon);S.Selected(b,item.id==view.selectedID) end
 end})
 view.empty=label(grid,'No resources match. Clear the search or choose another type.',190,150,516,90,15,S.muted);view.empty:SetWordWrap(true);view.empty:SetJustifyH('CENTER')
 local detail=place(CreateFrame('Frame',nil,root),root,0,0,896,395);view.detail=detail
 button(detail,'resourceBack','< Back to Codex',0,5,158,26,view.Back)
 view.icon=detail:CreateTexture(nil,'ARTWORK');place(view.icon,detail,176,0,44,44)
 view.name=label(detail,'',234,0,662,25,20,S.gold)
 view.profession=label(detail,'',234,29,662,18,12,S.muted)
 local information=place(S.Panel(detail),detail,0,64,330,296)
 view.sourceScroll=A.ScrollPanel.New(information);view.sourceScroll.frame:SetPoint('TOPLEFT',information,'TOPLEFT',8,-8);local infoBody=view.sourceScroll.body
 view.stats=label(infoBody,'',14,12,302,48,12,S.text);view.stats:SetWordWrap(true)
 view.last=label(infoBody,'',14,66,302,18,11,S.muted)
 label(infoBody,'Gathering sources',14,91,302,22,15,S.gold)
 for i=1,2 do
  local row=place(CreateFrame('Frame',nil,infoBody),infoBody,14,120+(i-1)*88,302,80)
  row.name=label(row,'',0,0,302,17,12,S.gold)
  row.requirement=label(row,'',0,20,302,17,11,S.text)
  row.summary=label(row,'',0,39,302,17,11,S.text)
  row.transition=label(row,'',0,58,302,17,11,S.muted)
  row:EnableMouse(true)
  A.SkillTooltip.Bind(row,'Gathering source',function() return row.node and {{node=row.node,details=row.details}} or {} end)
  view.sourceRows[i]=row
 end
 local zones=place(S.Panel(detail),detail,344,64,552,296)
 view.zoneTitle=label(zones,'Where to gather',14,12,524,23,17,S.gold)
 view.zoneHint=label(zones,'Ranked by known locations. Possible spawns, not live availability.',14,43,524,18,11,S.muted)
 view.zoneHeader=label(zones,'Zone',16,68,310,18,12,S.gold)
 local totals=label(zones,'Known / Personal',360,68,176,18,12,S.gold);totals:SetJustifyH('RIGHT');view.zoneTotals=totals;view.zones=zones
 view.zoneList=A.VirtualList.New(zones,{rowHeight=24,create=function(parent)
  local row=S.Button(parent,'',function(self) if self.zone then view.ShowZone(self.zone.mapID) end end,'quiet')
  row.label:ClearAllPoints();row.label:SetPoint('LEFT',row,'LEFT',4,0);row.label:SetJustifyH('LEFT')
  row.counts=label(row,'',348,0,174,24,11,S.muted);row.counts:SetJustifyH('RIGHT')
  S.Hint(row,'Show resource locations',function()
   if not row.zone then return '' end
   return safe(U.ZoneName(row.zone.mapID))..' / '..row.zone.count..' known locations. '..(row:IsEnabled() and 'Click to show this resource on the world map.' or select(2,mapAvailable(view.item,row.zone.mapID)) or 'Finish the current work before opening the map.')
  end)
  view.zoneRows[#view.zoneRows+1]=row;return row
 end,bind=function(row,zone,index,width)
  row.zone=zone;if not zone then return end
  row:SetText(safe(index..'. '..U.ZoneName(zone.mapID)));row.label:SetSize(width-190,24)
  row.counts:ClearAllPoints();place(row.counts,row,width-180,0,174,24);row.counts:SetText(zone.count..' / '..zone.confirmed)
  row:SetEnabled(view.item~=nil and not work() and WorldMapFrame~=nil and A.Map~=nil and A.Map.SetNodeFocus~=nil and mapAvailable(view.item,zone.mapID))
 end})
 view.zoneEmpty=label(zones,'No known locations yet. Import data on Welcome or gather this resource to record locations.',24,118,448,120,14,S.muted);view.zoneEmpty:SetWordWrap(true);view.zoneEmpty:SetJustifyH('CENTER')
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
  U.ReviewNodes(nodes,player,false,A.ResourceLibrary.ActionFilter(A.db,view.item,U.Filter()))
 end
 function view.Guide()
  if blocked() then return end
  local nodes,player=current()
  if A.Terrain and not A.Terrain.Allowed(player) then message('Move onto permitted terrain in the current zone before starting guidance.');return end
  local item=view.item;local markerFilter=A.ResourceLibrary.ActionFilter(A.db,item,U.Filter())
  local function work()
   local nearest,best,approach,failure;local ordered={}
   for _,n in ipairs(nodes) do local d=A.Client.Distance(player,n);if A.Store.Number(d) then ordered[#ordered+1]={node=n,distance=d} end end
   table.sort(ordered,function(a,b) return a.distance<b.distance end)
   for _,entry in ipairs(ordered) do
    if best and entry.distance-15>best then break end
    local n=entry.node;local destination,d
    if A.Terrain then
     destination,failure=A.Terrain.Approach(n,15)
     if destination then local path;path,d=A.Terrain.Path(player,destination);if not path then failure=d;d=nil end end
     if failure=='budget' then return nil,'Terrain search reached its budget before the nearest resource could be determined. Move nearer and try again.' end
    else destination=n;d=entry.distance end
    if A.Store.Number(d) and (not best or d<best) then nearest,best,approach=n,d,destination end
   end
   if not nearest then return nil,failure and ('Terrain-safe resource guidance unavailable: '..tostring(failure)) or 'Select this resource in Routes with readable current-zone locations.' end
   local target={mapID=approach.mapID,x=approach.x,y=approach.y,kind='gather',nodeKey=nearest.key,name=nearest.name or item.name,
    resourceKind=nearest.kind,materialID=nearest.materialID,objectID=nearest.objectID,resourcePosition={mapID=nearest.mapID,x=nearest.x,y=nearest.y}}
   local follower=A.Follower.New({name='Nearest '..item.name,mapID=nearest.mapID,points={target},loop=false},player,A.Client.Distance,{arrival=A.db.settings.arrival})
   if follower.status~='running' then return nil,follower.reason or 'No terrain-safe connection is available.' end
   follower.markerFilter=markerFilter;return follower
  end
  local function done(follower,reason)
   if not follower then message(reason);return end
   local currentPosition=A.Client.Position();follower.position=A.Store.Copy(currentPosition)
   if A.Terrain and not A.Terrain.Segment(currentPosition,follower:Target()) then follower.status='suspended';follower.reason='Position changed while planning. Resume to find a safe connection.' end
   if A.plan then A.plan.review=false end
   A.follower=follower
   if A.sessions then A.sessions:Begin(follower.route,A.Client.Timestamp()) end
   A.mapPreviewRoute=nil;if A.Map and A.Map.SetNodeFocus then A.Map.SetNodeFocus(nil);A.Map.Refresh(A.db,U.DisplayRoute(),A.follower) end
   U.frame:Hide();message(follower.reason or 'Guiding to a known '..item.name..' location.')
  end
  if A.PlanJob then
   message('Planning terrain-safe resource guidance...')
   return A.PlanJob(work,done,function(reason) message('Resource guidance failed: '..tostring(reason)) end)
  end
  return done(work())
 end
 button(detail,'codexPlan','Review resource route',0,369,206,26,view.Plan)
 button(detail,'codexGuide','Guide nearest',216,369,150,26,view.Guide)
 button(detail,'codexMap','Show current zone',376,369,206,26,function() local p=A.Client.Position();if p then view.ShowZone(p.mapID) end end)
 S.Hint(U.controls.codexPlan,'Resource route','Uses this resource and your Routes checkboxes. Stop current guidance first.')
 S.Hint(U.controls.codexMap,'Show resource markers',function() local player=A.Client.Position();if view.item and player then local _,reason=mapAvailable(view.item,player.mapID);if reason then return reason end end;return 'Uses your effective map-marker selections. Choose visible nodes in Node display.' end)
 S.Hint(U.controls.codexGuide,'Nearest known location','Uses your Routes checkboxes. Known locations are possible spawns, not live nodes.')
 function view.LayoutSources(count)
  local iw=view.sourceScroll:Layout(314,information:GetHeight()-16,112+math.min(2,count)*88)
  for _,t in ipairs({view.stats,view.last}) do t:SetWidth(iw-28) end
  for _,row in ipairs(view.sourceRows) do row:SetWidth(iw-28);for _,key in ipairs({'name','requirement','summary','transition'}) do row[key]:SetWidth(iw-28) end end
 end
 function view.Layout(width,height)
  local w,h=width-40,height-19;root:SetSize(w,h);grid:SetSize(w,h);detail:SetSize(w,h)
  local function move(f,p,x,y,fw,fh) f:ClearAllPoints();place(f,p,x,y,fw,fh) end
  move(view.searchLabel,grid,w-512,3,48,24);move(view.searchBox,grid,w-458,1,330,26);move(U.controls.resourceClear,grid,w-118,1,118,26)
  view.filterRows=w<896 and 2 or 1;local controls={kind,skill,scope,source}
  if view.filterRows==2 then
   for i,control in ipairs(controls) do move(control,grid,((i-1)%2)*(w+10)/2,37+math.floor((i-1)/2)*36,(w-10)/2,26) end
  else
   local fractions={190/896,210/896,210/896,256/896};local x=0
   for i,control in ipairs(controls) do local cw=(w-30)*fractions[i]/(866/896);move(control,grid,x,37,cw,26);x=x+cw+10 end
  end
  local top=view.filterRows==2 and 136 or 100
  move(view.info,grid,0,top-27,w,18);move(view.empty,grid,50,top,w-100,math.max(50,h-top))
  view.gridList.frame:ClearAllPoints();view.gridList.frame:SetPoint('TOPLEFT',grid,'TOPLEFT',0,-top)
  view.gridList:Layout(w,h-top,math.max(1,math.min(16,math.floor((w-20)/96))))
  move(view.name,detail,234,0,w-234,25);move(view.profession,detail,234,29,w-234,18);view.localInfo:SetWidth(w)
  local ph=h-99;information:SetSize(330,ph);zones:SetSize(w-344,ph)
  view.LayoutSources(view.item and #view.item.sources or 1)
  local zw=w-344;view.zoneTitle:SetWidth(zw-28);view.zoneHint:SetWidth(zw-28);view.zoneHeader:SetWidth(zw-218)
  move(totals,zones,zw-192,68,176,18)
  view.zoneList.frame:ClearAllPoints();view.zoneList.frame:SetPoint('TOPLEFT',zones,'TOPLEFT',12,-90);view.zoneList:Layout(zw-24,ph-100,1)
  move(view.zoneEmpty,zones,24,118,zw-48,math.max(40,ph-150))
  for _,e in ipairs({{'codexPlan',0,206},{'codexGuide',216,150},{'codexMap',376,206}}) do move(U.controls[e[1]],detail,e[2],h-26,e[3],26) end
 end
 function view.Refresh()
  local detailMode=view.mode=='detail';local p=A.Client.Position()
  local options=not detailMode and {scope=view.scope,source=view.source,skill=view.skill,mapID=p and p.mapID} or {source=view.source}
  local model=A.ResourceLibrary.Query(A.db,detailMode and 'all' or view.kind,detailMode and '' or view.search,options)
  view.model=model;view.item=nil
  for _,item in ipairs(model.items) do if item.id==view.selectedID then view.item=item;break end end
  if view.mode=='detail' and not view.item then view.mode='grid';U.layoutsKey=nil;U.Refresh();return end
  show(grid,view.mode=='grid');show(detail,view.mode=='detail');kind:SetValue(view.kind);skill:SetValue(view.skill);scope:SetValue(view.scope);source:SetValue(view.source)
  U.zone:SetText('Node Codex  -  Browse resources; choose farming materials in Routes')
  if view.mode=='grid' then
   local query=table.concat({view.kind,view.scope,view.source,view.skill,view.search,tostring(view.scope=='current' and p and p.mapID or '')},'/')
   view.info:SetText(#model.items..' resources / Scroll to browse. Route and marker choices remain unchanged.')
   view.gridList:SetItems(model.items,query~=view.query);view.query=query
   view.empty:SetText(view.scope=='current' and not p and 'Position unavailable. Choose All zones to browse the catalogue.' or 'No resources match. Clear the search or choose another filter.')
   show(view.empty,#model.items==0);return
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
    row.transition:SetText(safe(d.transition or (d.source=='profession' and 'Profession not learned' or d.source=='reference' and ('Source: '..A.Resources.referenceLabel) or 'Source: Unknown')))
   else row.node=nil;row.details=nil end
  end
  view.LayoutSources(#item.sources)
  view.zoneList:SetItems(item.zones,view.zoneItem~=item.id);view.zoneItem=item.id
  show(view.zoneEmpty,#item.zones==0)

 end
 return view
end
