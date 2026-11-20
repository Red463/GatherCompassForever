local _,A=...
local S=A.Skin;local V={};A.NodeDisplayView=V
function V.New(parent,U)
 local v={page='filters',opacityLabels={},sizeLabels={}}
 local opacityBindings,sizeBindings={},{}
 local pageTop,panelHeight,panelGap,bottomPadding=106,330,16,9
 local pageHeight=pageTop+panelHeight+bottomPadding
 local function place(f,p,x,y,w,h) f:SetPoint('TOPLEFT',p,'TOPLEFT',x,-y);f:SetSize(w,h);return f end
 local function label(p,text,x,y,w,h,size,color) return place(S.Label(p,text,size or 12,color or S.text),p,x,y,w,h) end
 local scroller=A.ScrollPanel.New(parent);v.scroller=scroller;v.frame=scroller.frame
 place(v.frame,parent,20,19,896,pageHeight);local f=scroller.body;f:SetSize(896,pageHeight)
 label(f,'Node display',0,0,500,26,18,S.gold)
 v.subtitle=label(f,'Set how known locations and guidance appear on each map.',0,33,896,20,12,S.muted)
 local function check(p,key,text,x,y,width)
  local b=place(S.Check(p,text,U.actions[key]),p,x,y,24,24);b.label:SetWidth(width);b:SetHitRectInsets(0,-width,0,0);U.controls[key]=b;return b
 end
 local function dropdown(p,key,items,x,y,w)
  local b=place(S.Dropdown(p,items,U.actions[key]),p,x,y,w,26);U.controls[key]=b;return b
 end
 local function sizes(values,suffix) local t={};for _,n in ipairs(values) do t[#t+1]={value=n,label=n..suffix} end;return t end
 local function opacity(p,key,setting,text,x,y,w)
  v.opacityLabels[key]=label(p,text,x,y,w,20,12,S.muted)
  U.controls[key]=place(S.Slider(p,0,100,5,U.actions[key],function(n) return n..'%' end),p,x,y+30,w-12,12)
  opacityBindings[#opacityBindings+1]={key=key,setting=setting,text=text}
 end
 local function size(p,key,setting,text,x,y,w,inline)
  v.sizeLabels[key]=label(p,text,x,y,inline and 140 or w,20,12,S.muted)
  local slider=S.Slider(p,4,32,1,function(_,value)
   if not U.syncingOptions then U.actions[key](value) end
  end)
  U.controls[key]=place(slider,p,x+(inline and 150 or 0),y+(inline and 6 or 30),w-(inline and 162 or 12),12)
  sizeBindings[#sizeBindings+1]={key=key,setting=setting,text=text}
 end
 function v.SetPage(page) v.page=page;U.Refresh() end
 for i,page in ipairs({'filters','world','mini'}) do
  local b=place(S.Button(f,page=='filters' and 'Visible nodes' or page=='world' and 'World map' or 'Minimap',function() v.SetPage(page) end,'quiet'),f,(i-1)*164,66,154,26)
  U.controls[page=='filters' and 'displayFilters' or page=='world' and 'displayWorld' or 'displayMini']=b
 end
 v.filters=A.MarkerFiltersView.New(f,U);v.filters.frame:SetPoint('TOPLEFT',f,'TOPLEFT',0,-pageTop)
 v.world=place(CreateFrame('Frame',nil,f),f,0,pageTop,896,panelHeight)
 v.mini=place(CreateFrame('Frame',nil,f),f,0,pageTop,896,panelHeight)
 local world=place(S.Panel(v.world),v.world,0,0,438,panelHeight)
 check(world,'nodeWorld','Show node icons',14,14,350)
 check(world,'nodeGroupWorld','Group overlapping icons',14,52,350)
 size(world,'nodeWorldIconSize','worldIconSize','Icon size',18,98,394,true)
 opacity(world,'nodeWorldOpacity','worldIconOpacity','Icon opacity',18,143,394)
 label(world,'Route guidance',18,216,400,23,16,S.gold)
 opacity(world,'nodeWorldLineOpacity','worldLineOpacity','Line opacity',18,251,184)
 opacity(world,'nodeWorldHeatOpacity','worldHeatOpacity','Heatmap opacity',230,251,184)
 local preview=place(S.Panel(v.world),v.world,454,0,442,panelHeight)
 label(preview,'Marker preview',18,14,400,23,16,S.gold)
 v.previewCaption=label(preview,'Appearance example',18,242,400,22,11,S.muted)
 local worldHelp=label(preview,'Hover over a grouped badge on the world map to see its resources. Zoom in to separate nearby locations.',18,271,400,42,12,S.muted);worldHelp:SetWordWrap(true)
 v.previewCanvas=place(CreateFrame('Frame',nil,preview),preview,18,48,406,180);v.previewCanvas:SetClipsChildren(true);v.previewCanvas:EnableMouse(false)
 S.Fill(v.previewCanvas,{.12,.17,.10,1},'BACKGROUND',-8);v.previewArt=A.MapArt.New(v.previewCanvas)
 v.previewFallback=label(v.previewCanvas,'Map artwork unavailable - marker sample',12,148,380,22,11,S.muted)
 v.worldExamples={}
 for i=1,3 do
  local icon=v.previewCanvas:CreateTexture(nil,'ARTWORK');place(icon,v.previewCanvas,({174,188,282})[i],({88,94,54})[i],24,24);icon:SetTexture(A.Resources.Icon({kind='herb',materialID=i==1 and 'gm:herb:402' or 'gm:herb:403'}));v.worldExamples[i]=icon
 end
 v.worldCount=label(v.previewCanvas,'2',190,74,30,20,12,S.gold)
 local mini=place(S.Panel(v.mini),v.mini,0,0,438,panelHeight)
 check(mini,'nodeMini','Show node markers',12,8,180);check(mini,'nodeIcon','Show icons',236,8,160)
 check(mini,'nodeGroupMini','Group overlapping icons',12,40,382)
 label(mini,'Outline',18,76,124,26)
 dropdown(mini,'nodeOutline',{{value='ring',label='Ring'},{value='square',label='Square'},{value='none',label='None (icon only)'}},164,76,248)
 size(mini,'nodeOutlineSize','outlineSize','Outline size',18,110,184)
 size(mini,'nodeIconSize','iconSize','Icon size',230,110,184)
 label(mini,'Hide icons within',18,178,142,26)
 local distances=sizes({0,5,10,15,20,30,40,60,80,100},' yards');distances[1].label='Never'
 dropdown(mini,'nodeDistance',distances,164,178,248)
 opacity(mini,'nodeMiniIconOpacity','miniIconOpacity','Icon opacity',18,214,184)
 opacity(mini,'nodeOutlineOpacity','miniOutlineOpacity','Outline opacity',230,214,184)
 local miniHelp=label(mini,'Nearby icons hide within the selected distance. Outlines stay at their actual locations.',18,284,396,34,12,S.muted);miniHelp:SetWordWrap(true)
 local guidance=place(S.Panel(v.mini),v.mini,454,0,442,panelHeight)
 label(guidance,'Route guidance',18,14,400,23,16,S.gold)
 check(guidance,'nodeRouteLine','Show route overlay',14,46,388)
 opacity(guidance,'nodeMiniLineOpacity','miniLineOpacity','Line opacity',18,88,184)
 opacity(guidance,'nodeMiniHeatOpacity','miniHeatOpacity','Heatmap opacity',230,88,184)
 label(guidance,'Choose Lines or Heatmap in Routes.',18,166,236,22,12,S.muted)
 label(guidance,'Marker preview',284,166,136,22,12,S.gold)
 local field=place(S.Panel(guidance),guidance,284,194,136,90)
 v.miniOutline=field:CreateTexture(nil,'OVERLAY');v.miniOutline:SetPoint('CENTER',field,'CENTER');v.miniOutline:SetSize(36,36)
 v.miniIcon=field:CreateTexture(nil,'ARTWORK');v.miniIcon:SetPoint('CENTER',field,'CENTER');v.miniIcon:SetSize(20,20);v.miniIcon:SetTexture(A.Resources.Icon({kind='herb',materialID='gm:herb:402'}))
 v.miniCount=label(field,'3',77,17,28,20,12,S.gold)
 S.Hint(U.controls.nodeDistance,'Keep native tracking visible','Hide nearby resource icons and grouped counts. Hollow outlines remain at their real known locations.')
 S.Hint(U.controls.nodeRouteLine,'Minimap route overlay','Applies to both Lines and Heatmap. Node-marker visibility is independent of route guidance.')
 function v.Layout(width,height)
  local w,h=width-40,height-19;v.stacked=w-(h<pageHeight and 20 or 0)<896
  local content=v.stacked and pageHeight+panelHeight+panelGap or pageHeight
  local available=scroller:Layout(w,h,v.page=='filters' and h or content)
  v.subtitle:SetWidth(available);v.filters.Layout(available,math.max(250,h-pageTop))
  v.world:SetSize(available,content-pageTop);v.mini:SetSize(available,content-pageTop)
  local left=v.stacked and math.max(0,(available-442)/2) or math.max(0,(available-896)/2)
  for _,e in ipairs({{world,v.world,false},{preview,v.world,true},{mini,v.mini,false},{guidance,v.mini,true}}) do
   e[1]:ClearAllPoints();e[1]:SetPoint('TOPLEFT',e[2],'TOPLEFT',left+(e[3] and not v.stacked and 454 or 0),e[3] and v.stacked and -(panelHeight+panelGap) or 0)
  end
 end
 function v.Refresh()
  local s=A.Resources.Settings(A.db.settings);local worldPage=v.page=='world'
  if v.page=='filters' then v.filters.frame:Show();v.world:Hide();v.mini:Hide();if U.tab=='nodes' then v.filters.Refresh() end else v.filters.frame:Hide();if worldPage then v.world:Show();v.mini:Hide() else v.world:Hide();v.mini:Show() end end
  S.Selected(U.controls.displayFilters,v.page=='filters');S.Selected(U.controls.displayWorld,worldPage);S.Selected(U.controls.displayMini,v.page=='mini')
  for key,value in pairs({nodeWorld=s.world,nodeMini=s.mini,nodeIcon=s.icon,nodeGroupWorld=s.groupWorld,nodeGroupMini=s.groupMini,nodeRouteLine=s.routeLines}) do U.controls[key]:SetChecked(value) end
  for key,value in pairs({nodeOutline=s.outline,nodeDistance=s.hideDistance}) do U.controls[key]:SetValue(value) end
  U.syncingOptions=true
  for _,binding in ipairs(sizeBindings) do
   local value=s[binding.setting]
   U.controls[binding.key]:SetValue(value);v.sizeLabels[binding.key]:SetText(binding.text..': '..value)
  end
  for _,binding in ipairs(opacityBindings) do
   local value=math.floor(s[binding.setting]*100+.5)
   U.controls[binding.key]:SetValue(value);v.opacityLabels[binding.key]:SetText(binding.text..': '..value..'%')
  end
  U.syncingOptions=false
  for _,key in ipairs({'nodeGroupWorld','nodeWorldIconSize','nodeWorldOpacity'}) do U.controls[key]:SetEnabled(s.world) end
  for _,key in ipairs({'nodeGroupMini','nodeOutline','nodeIconSize','nodeDistance','nodeMiniIconOpacity'}) do U.controls[key]:SetEnabled(s.mini) end
  U.controls.nodeIcon:SetEnabled(s.mini and s.outline~='none')
  U.controls.nodeOutlineSize:SetEnabled(s.mini and s.outline~='none');U.controls.nodeOutlineOpacity:SetEnabled(s.mini and s.outline~='none')
  U.controls.nodeMiniLineOpacity:SetEnabled(s.routeLines);U.controls.nodeMiniHeatOpacity:SetEnabled(s.routeLines)
  for i,icon in ipairs(v.worldExamples) do
   local size=s.worldIconSize+(s.groupWorld and i==1 and 8 or 0);icon:SetSize(size,size);icon:SetAlpha(s.worldIconOpacity)
   if s.world and (i==1 or i==3 or not s.groupWorld) then icon:Show() else icon:Hide() end
  end
  v.worldExamples[1]:SetTexture(A.Resources.Icon({kind='herb',materialID='gm:herb:402'}))
  if s.world and s.groupWorld then v.worldCount:Show();v.worldCount:SetAlpha(s.worldIconOpacity) else v.worldCount:Hide() end
  if U.tab=='nodes' and worldPage then
   local player=A.Client.Position();local aspect=v.previewArt.aspect or 1.5;local half=.25*180/406*aspect
   v.previewArt:Draw(player and player.mapID,{left=.25,right=.75,top=.5-half,bottom=.5+half},406,180)
   if v.previewArt.available then v.previewFallback:Hide() else v.previewFallback:Show() end
  end
  v.miniOutline:SetSize(s.outlineSize,s.outlineSize);v.miniIcon:SetSize(s.iconSize,s.iconSize)
  v.miniIcon:SetAlpha(s.miniIconOpacity);v.miniCount:SetAlpha(s.miniIconOpacity)
  if s.mini and s.icon then v.miniIcon:Show() else v.miniIcon:Hide() end
  if s.mini and s.icon and s.groupMini then v.miniCount:Show() else v.miniCount:Hide() end
  if s.mini and s.outline~='none' then v.miniOutline:Show() else v.miniOutline:Hide() end
  v.miniOutline:SetTexture(S.media..(s.outline=='square' and 'NodeSquare' or 'NodeRing'));v.miniOutline:SetVertexColor(.3,.85,.35);v.miniOutline:SetAlpha(s.miniOutlineOpacity)
  if U.tab=='nodes' then U.zone:SetText('Node display  -  '..(v.page=='filters' and 'Visible nodes' or worldPage and 'World map' or 'Minimap')) end
 end
 U.nodeOpacityLabels=v.opacityLabels
 return v
end
