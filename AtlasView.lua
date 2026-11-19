local _, A = ...
local S=A.Skin
local V={};A.AtlasView=V
local function safe(value) return tostring(value or ''):gsub('|','||') end
local function place(f,parent,x,y,w,h) f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);f:SetSize(w,h);return f end
local function label(parent,text,x,y,w,h,size,color)
 return place(S.Label(parent,text,size or 12,color or S.text),parent,x,y,w,h)
end
local function visible(frame,on) if on then frame:Show() else frame:Hide() end end
local function active()
 local f=A.follower;return f and (f.status=='running' or f.status=='paused' or f.status=='suspended')
end
local function age(value)
 if not A.Store.Number(value) or value<=0 then return 'unavailable' end
 local ok,now=pcall(function() return time and time() end)
 if not ok or not A.Store.Number(now) then return 'recorded' end
 local seconds=math.max(0,now-value)
 if seconds<60 then return 'just now' elseif seconds<3600 then return math.floor(seconds/60)..'m ago'
 elseif seconds<86400 then return math.floor(seconds/3600)..'h ago' end
 return math.floor(seconds/86400)..'d ago'
end
function V.New(parent,U)
 local view={scope='current',skill='all',sort='nearest',detail='locations',resourcePage=1,detailPage=1,rows={},detailRows={}}
 local f=place(CreateFrame('Frame',nil,parent),parent,20,19,710,377);view.frame=f
 local function button(parent,key,text,x,y,w,h,fn,style)
  local b=place(S.Button(parent,text,fn,style),parent,x,y,w,h or 24);U.controls[key]=b;return b
 end
 local function dropdown(key,items,x,w,fn)
  local d=place(S.Dropdown(f,items,fn),f,x,59,w,26);U.controls[key]=d;return d
 end
 local function message(text) A.status=text;U.Refresh() end
 local function blocked(navigation)
  if A.editor or A.recording or A.recordedDraft then message('Save or discard the current draft or recording first.');return true end
  if navigation and active() then message('Stop the current route before planning or guiding to another resource.');return true end
 end
 function view.Select(id) view.selectedID=id;view.selectedNode=nil;view.detailPage=1;U.Refresh() end
 function view.SetScope(value) view.scope=value;view.resourcePage=1;view.detailPage=1;view.selectedNode=nil;U.Refresh() end
 function view.CurrentNodes()
  local player=A.Client.Position();local nodes={};local group=view.group
  if not player or not group then return nodes,player end
  for _,node in ipairs(group.nodes) do if node.mapID==player.mapID then nodes[#nodes+1]=node end end
  return nodes,player
 end
 function view.Plan()
  if blocked(true) then return end
  local nodes,player=view.CurrentNodes()
  if not player or #nodes==0 then message('Plan a route after entering a zone containing this resource.');return end
  local route,reason=A.Planner.Generate(nodes,player,A.Client.Distance,{zoneName=U.ZoneName(player.mapID),routes=A.db.routes})
  if not route then message(reason);return end
  A.follower=nil
  if A.Map and A.Map.SetNodeFocus then A.Map.SetNodeFocus(nil) end
  U.Edit(route);message((reason and reason..' ' or '')..'Resource route draft ready. Review it, then save and start when ready.')
 end
 function view.Guide()
  if blocked(true) then return end
  local nodes,player=view.CurrentNodes();local nearest,best
  for _,node in ipairs(nodes) do
   local distance=A.Client.Distance(player,node)
   if A.Store.Number(distance) and (not best or distance<best) then nearest,best=node,distance end
  end
  if not nearest then message('Nearest guidance requires a readable known location in your current zone.');return end
  local target={mapID=nearest.mapID,x=nearest.x,y=nearest.y,kind='gather',nodeKey=nearest.key,name=nearest.name or view.group.name}
  A.follower=A.Follower.New({name='Nearest '..view.group.name,mapID=nearest.mapID,loop=false,points={target}},player,A.Client.Distance,{arrival=A.db.settings.arrival})
  A.mapPreviewRoute=nil;if A.Map and A.Map.SetNodeFocus then A.Map.SetNodeFocus(nil) end
  U.frame:Hide();message('Guiding to a known '..view.group.name..' location.')
 end
 function view.ShowMap()
  if blocked(false) then return end
  local group=view.group;if not group or not WorldMapFrame then message('Select a resource with known locations first.');return end
  local node=view.selectedNode or group.nearest
  local mapID=node and node.mapID or A.Store.Number(view.scope) and view.scope or group.locations[1].node.mapID
  if not A.Map or not A.Map.SetNodeFocus then message('World-map resource focus is unavailable.');return end
  local ok,reason=A.Map.SetNodeFocus(mapID,group.materialIDs,node and node.key,U.Filter().source)
  if not ok then message(reason or 'World-map resource focus is unavailable.');return end
  WorldMapFrame:Show();if WorldMapFrame.SetMapID then WorldMapFrame:SetMapID(mapID) end
  A.Map.Refresh(A.db,U.DisplayRoute(),A.follower);U.frame:Hide()
  message('World map: '..group.name..' known locations in '..U.ZoneName(mapID)..'. Close the map to restore its normal display.')
 end
 label(f,'Resource guide',0,0,400,26,18,S.gold)
 view.info=label(f,'',0,31,530,18,12,S.muted)
 button(f,'atlasMap','World map',548,1,162,26,function()
  if A.Map and A.Map.SetNodeFocus then A.Map.SetNodeFocus(nil) end
  U.actions.map();if WorldMapFrame then U.frame:Hide() end
 end)
 dropdown('atlasScope',function()
  local options={{value='current',label='Current zone'},{value='all',label='All zones'}}
  if A.Store.Number(view.scope) then options[#options+1]={value=view.scope,label=U.ZoneName(view.scope)} end
  return options
 end,0,240,view.SetScope)
 dropdown('atlasSkill',{{value='all',label='All resources'},{value='gatherable',label='Can gather'},{value='skillups',label='Can gain skill'}},250,216,function(value) view.skill=value;view.resourcePage=1;view.detailPage=1;U.Refresh() end)
 dropdown('atlasSort',{{value='nearest',label='Nearest first'},{value='name',label='Name'},{value='difficulty',label='Skill difficulty'},{value='gathers',label='Personal gathers'},{value='recent',label='Last gathered'}},476,234,function(value) view.sort=value;view.resourcePage=1;U.Refresh() end)
 for i=1,4 do
  local row=button(f,'atlasResource'..i,'',0,101+(i-1)*57,330,54,function(self) if self.group then view.Select(self.group.id) end end,'quiet')
  row.label:ClearAllPoints();place(row.label,row,44,3,274,18);row.label:SetJustifyH('LEFT')
  row.icon=row:CreateTexture(nil,'ARTWORK');place(row.icon,row,8,13,28,28)
  row.skill=label(row,'',44,23,274,15,11,S.muted);row.counts=label(row,'',44,39,274,14,11,S.muted)
  S.Hint(row,'Resource details',function()
   local g=row.group;if not g then return '' end
   return g.name..'\n'..g.skill.requirement..'\n'..g.skill.summary..(g.skill.transition and ('\n'..g.skill.transition) or '')..'\n'..g.count..' known locations / '..g.confirmed..' personal locations / '..g.harvests..' personal gathers.'
  end)
  view.rows[i]=row
 end
 view.empty=label(f,'No resources match. Adjust the source, materials or skill filter.',12,135,306,130,13,S.muted);view.empty:SetWordWrap(true);view.empty:SetJustifyH('CENTER')
 local detail=place(S.Panel(f),f,344,99,366,241);view.detailFrame=detail
 view.name=label(detail,'',12,9,342,23,16,S.gold)
 view.summary=label(detail,'',12,35,342,17,11,S.text)
 view.history=label(detail,'',12,56,342,17,11,S.muted)
 local mode=place(S.Dropdown(detail,{{value='locations',label='Known locations'},{value='zones',label='Zones for this resource'}},function(value) view.detail=value;view.detailPage=1;view.selectedNode=nil;U.Refresh() end),detail,12,80,342,26);U.controls.atlasDetail=mode
 for i=1,5 do
  local row=button(detail,'atlasLocation'..i,'',10,111+(i-1)*21,346,20,function(self)
   if not self.entry then return end
   if view.detail=='zones' then view.detail='locations';view.SetScope(self.entry.mapID)
   else view.selectedNode=self.entry.node;U.Refresh() end
  end,'quiet')
  row.label:ClearAllPoints();place(row.label,row,3,0,247,20);row.label:SetJustifyH('LEFT')
  row.right=label(row,'',250,0,90,20,11,S.muted);row.right:SetJustifyH('RIGHT')
  S.Hint(row,'Known location',function()
   local e=row.entry;if not e then return '' end
   if e.node then return U.ZoneName(e.node.mapID)..string.format(' / %.1f, %.1f',e.node.x*100,e.node.y*100)..'\n'..(e.node.confirmed and 'Personally gathered' or 'Imported')..' / '..(e.node.count or 0)..' gathers.\nLast gathered: '..age(e.node.lastGathered)..'.' end
   return U.ZoneName(e.mapID)..' / '..e.count..' known / '..e.confirmed..' personal locations.\nClick to browse this zone.'
  end)
  view.detailRows[i]=row
 end
 button(detail,'atlasDetailPrev','<',10,218,24,20,function() view.detailPage=math.max(1,view.detailPage-1);U.Refresh() end,'quiet')
 button(detail,'atlasDetailNext','>',332,218,24,20,function() view.detailPage=view.detailPage+1;U.Refresh() end,'quiet')
 view.detailPageLabel=label(detail,'',42,219,282,18,11,S.dim);view.detailPageLabel:SetJustifyH('CENTER')
 button(f,'prevAtlas','<',0,348,26,24,function() view.resourcePage=math.max(1,view.resourcePage-1);U.Refresh() end,'quiet')
 button(f,'nextAtlas','>',304,348,26,24,function() view.resourcePage=view.resourcePage+1;U.Refresh() end,'quiet')
 view.pageLabel=label(f,'',32,349,268,22,11,S.dim);view.pageLabel:SetJustifyH('CENTER')
 button(f,'atlasPlan','Plan route',344,348,108,24,view.Plan)
 button(f,'atlasShow','Show map',460,348,108,24,view.ShowMap)
 button(f,'atlasGuide','Guide nearest',576,348,134,24,view.Guide)
 S.Hint(U.controls.atlasPlan,'Plan this resource','Creates a draft from matching current-zone locations. Stop active navigation and finish current work first. Sidebar filters and saved routes stay intact.')
 S.Hint(U.controls.atlasGuide,'Guide to nearest known location','Starts one-point guidance in your current zone. A known coordinate does not tell us whether a resource is currently spawned. Stop active navigation and finish current work first.')
 S.Hint(U.controls.atlasShow,'Show this resource on the map','Temporarily focuses world-map icons for this resource. Close the map to restore normal markers; minimap guidance continues.')
 function view.Refresh()
  local player=A.Client.Position();local skills,context=A.Resources.Skills();local w,h
  if player then w,h=A.Client.Size(player.mapID) end
  local function distance(a,b)
   if w and h and A.Store.Position(a) and A.Store.Position(b) and a.mapID==b.mapID then return math.sqrt(((a.x-b.x)*w)^2+((a.y-b.y)*h)^2) end
  end
  view.model=A.Atlas.Query(A.db,player,U.Filter(),{zone=view.scope,skill=view.skill,sort=view.sort},skills,context,distance)
  local groups=view.model.groups;local pages=math.max(1,math.ceil(#groups/4));view.resourcePage=math.max(1,math.min(view.resourcePage,pages))
  view.group=nil
  for _,g in ipairs(groups) do if g.id==view.selectedID then view.group=g;break end end
  view.group=view.group or groups[1];view.selectedID=view.group and view.group.id or nil
  for i,row in ipairs(view.rows) do
   local g=groups[(view.resourcePage-1)*4+i];row.group=g;visible(row,g~=nil)
   if g then row:SetText(safe(g.name));row.icon:SetTexture(g.icon);row.skill:SetText(safe(g.skill.summary));row.skill:SetTextColor(unpack(g.skill.color));row.counts:SetText(g.count..' known / '..g.confirmed..' personal');S.Selected(row,g.id==view.selectedID) end
  end
  visible(view.empty,#groups==0)
  view.empty:SetText(not player and view.scope=='current' and 'Position unavailable. Choose All zones to browse known resources.' or 'No resources match. Adjust the source, materials or skill filter.')
  view.info:SetText(#groups..' resources / '..view.model.totalLocations..' known locations / Spawn history')
  U.controls.atlasScope:SetValue(view.scope);U.controls.atlasSkill:SetValue(view.skill);U.controls.atlasSort:SetValue(view.sort);mode:SetValue(view.detail)
  U.controls.prevAtlas:SetEnabled(view.resourcePage>1);U.controls.nextAtlas:SetEnabled(view.resourcePage<pages);view.pageLabel:SetText('Resources '..view.resourcePage..' / '..pages)
  local g=view.group;visible(detail,g~=nil)
  if g then
   view.name:SetText(safe(g.name));view.summary:SetText(safe(g.skill.summary..(g.skill.transition and (' / '..g.skill.transition) or '')));view.summary:SetTextColor(unpack(g.skill.color))
   view.history:SetText(g.harvests..' personal gathers / Last: '..age(g.lastGathered))
   local found=false;for _,e in ipairs(g.locations) do if view.selectedNode and e.node.key==view.selectedNode.key then view.selectedNode=e.node;found=true;break end end
   if not found then view.selectedNode=nil end
   local entries=view.detail=='zones' and g.zones or g.locations;local detailPages=math.max(1,math.ceil(#entries/5));view.detailPage=math.max(1,math.min(view.detailPage,detailPages))
   for i,row in ipairs(view.detailRows) do
    local e=entries[(view.detailPage-1)*5+i];row.entry=e;visible(row,e~=nil)
    if e then
     if e.node then
      row:SetText(safe(U.ZoneName(e.node.mapID)..string.format(' %.1f, %.1f',e.node.x*100,e.node.y*100)));row.right:SetText(e.distance and (math.floor(e.distance+.5)..' yd') or 'Known spawn');S.Selected(row,view.selectedNode and view.selectedNode.key==e.node.key)
     else row:SetText(safe(U.ZoneName(e.mapID)));row.right:SetText(e.count..' known');S.Selected(row,view.scope==e.mapID) end
    end
   end
   view.detailPageLabel:SetText(view.detail=='zones' and ('Zones '..view.detailPage..' / '..detailPages) or ('Locations '..view.detailPage..' / '..detailPages))
   U.controls.atlasDetailPrev:SetEnabled(view.detailPage>1);U.controls.atlasDetailNext:SetEnabled(view.detailPage<detailPages)
  else for _,row in ipairs(view.detailRows) do row.entry=nil;row:Hide() end end
  local work=A.editor or A.recording or A.recordedDraft;local canNavigate=g and g.nearest~=nil and player~=nil and not work and not active()
  U.controls.atlasPlan:SetEnabled(not not canNavigate);U.controls.atlasGuide:SetEnabled(not not canNavigate)
  U.controls.atlasShow:SetEnabled(g~=nil and not work)
 end
 return view
end
