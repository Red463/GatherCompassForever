local _,A=...
local S=A.Skin;local V={};A.NodeDisplayView=V
function V.New(parent,U)
 local v={page='world',opacityLabels={}}
 local function place(f,p,x,y,w,h) f:SetPoint('TOPLEFT',p,'TOPLEFT',x,-y);f:SetSize(w,h);return f end
 local function label(p,text,x,y,w,h,size,color) return place(S.Label(p,text,size or 12,color or S.text),p,x,y,w,h) end
 local scroller=A.ScrollPanel.New(parent);v.scroller=scroller;v.frame=scroller.frame
 place(v.frame,parent,20,19,896,395);local f=scroller.body;f:SetSize(896,395)
 label(f,'Node display',0,0,500,26,18,S.gold)
 label(f,'Set how known locations and guidance appear on each map.',0,33,896,20,12,S.muted)
 local function check(p,key,text,x,y,width)
  local b=place(S.Check(p,text,U.actions[key]),p,x,y,24,24);b.label:SetWidth(width);b:SetHitRectInsets(0,-width,0,0);U.controls[key]=b;return b
 end
 local function dropdown(p,key,items,x,y,w)
  local b=place(S.Dropdown(p,items,U.actions[key]),p,x,y,w,26);U.controls[key]=b;return b
 end
 local function sizes(values,suffix) local t={};for _,n in ipairs(values) do t[#t+1]={value=n,label=n..suffix} end;return t end
 local function opacity(p,key,text,x,y,w)
  v.opacityLabels[key]=label(p,text,x,y,w,20,12,S.muted)
  U.controls[key]=place(S.Slider(p,0,100,5,U.actions[key],function(n) return n..'%' end),p,x,y+30,w-12,12)
 end
 function v.SetPage(page) v.page=page;U.Refresh() end
 for i,page in ipairs({'world','mini'}) do
  local b=place(S.Button(f,page=='world' and 'World map' or 'Minimap',function() v.SetPage(page) end,'quiet'),f,(i-1)*164,66,154,26)
  U.controls[page=='world' and 'displayWorld' or 'displayMini']=b
 end
 v.world=place(CreateFrame('Frame',nil,f),f,0,106,896,280)
 v.mini=place(CreateFrame('Frame',nil,f),f,0,106,896,280)
 local world=place(S.Panel(v.world),v.world,0,0,438,280)
 check(world,'nodeWorld','Show node icons',14,14,350)
 check(world,'nodeGroupWorld','Group overlapping icons',14,52,350)
 label(world,'Icon size',18,98,120,26);dropdown(world,'nodeWorldIconSize',sizes({10,12,14,16,18,20,24},' px'),168,98,244)
 opacity(world,'nodeWorldOpacity','World-map icons',18,143,394)
 local help=label(world,'Icons only on the world map. Hover a grouped badge to see its resources; zoom in to separate nearby locations.',18,219,394,48,12,S.muted);help:SetWordWrap(true)
 local preview=place(S.Panel(v.world),v.world,454,0,442,280)
 label(preview,'Marker preview',18,14,400,23,16,S.gold)
 label(preview,'Mixed groups use a neutral badge and a count.',18,242,400,22,11,S.muted)
 v.worldExamples={}
 for i=1,3 do
  local icon=preview:CreateTexture(nil,'ARTWORK');place(icon,preview,130+i*26,100+(i%2)*14,24,24);icon:SetTexture(A.Resources.Icon({kind='herb',materialID=i==1 and 'gm:herb:402' or 'gm:herb:403'}));v.worldExamples[i]=icon
 end
 v.worldCount=label(preview,'3',189,99,30,20,12,S.gold)
 local mini=place(S.Panel(v.mini),v.mini,0,0,438,280)
 check(mini,'nodeMini','Show node markers',12,8,180);check(mini,'nodeIcon','Show icons',236,8,160)
 check(mini,'nodeGroupMini','Group overlapping icons',12,40,382)
 label(mini,'Outline',18,76,124,26)
 dropdown(mini,'nodeOutline',{{value='ring',label='Ring'},{value='square',label='Square'},{value='none',label='None (icon only)'}},164,76,248)
 label(mini,'Outline size',18,110,124,26);dropdown(mini,'nodeOutlineSize',sizes({20,24,28,32,36,40},' px'),164,110,248)
 label(mini,'Icon size',18,144,124,26);dropdown(mini,'nodeIconSize',sizes({10,12,14,16,18,20,24},' px'),164,144,248)
 label(mini,'Hide icons within',18,178,142,26)
 local distances=sizes({0,5,10,15,20,30,40,60,80,100},' yards');distances[1].label='Never'
 dropdown(mini,'nodeDistance',distances,164,178,248)
 opacity(mini,'nodeMiniIconOpacity','Minimap icons',18,214,184);opacity(mini,'nodeOutlineOpacity','Minimap outlines',230,214,184)
 local guidance=place(S.Panel(v.mini),v.mini,454,0,442,280)
 label(guidance,'Route guidance',18,14,400,23,16,S.gold)
 check(guidance,'nodeRouteLine','Show route overlay',14,46,388)
 opacity(guidance,'nodeRouteOpacity','Route overlay',18,88,396)
 local note=label(guidance,'Choose Lines or Heatmap in Routes. Nearby icons hide; hollow outlines stay at the actual locations.',18,166,236,68,12,S.muted);note:SetWordWrap(true)
 local field=place(S.Panel(guidance),guidance,284,168,136,90)
 v.miniOutline=field:CreateTexture(nil,'OVERLAY');v.miniOutline:SetPoint('CENTER',field,'CENTER');v.miniOutline:SetSize(36,36)
 v.miniIcon=field:CreateTexture(nil,'ARTWORK');v.miniIcon:SetPoint('CENTER',field,'CENTER');v.miniIcon:SetSize(20,20);v.miniIcon:SetTexture(S.media..'Icon')
 v.miniCount=label(field,'3',77,17,28,20,12,S.gold)
 S.Hint(U.controls.nodeDistance,'Keep native tracking visible','Hide nearby resource icons and grouped counts. Hollow outlines remain at their real known locations.')
 S.Hint(U.controls.nodeRouteLine,'Minimap route overlay','Applies to both Lines and Heatmap. Node-marker visibility is independent of route guidance.')
 function v.Layout(width,height)
  local w,h=width-40,height-19;v.stacked=w-(h<395 and 20 or 0)<896
  local content=v.stacked and 682 or 395;local available=scroller:Layout(w,h,content)
  v.world:SetSize(available,content-106);v.mini:SetSize(available,content-106)
  local left=v.stacked and math.max(0,(available-442)/2) or math.max(0,(available-896)/2)
  for _,e in ipairs({{world,v.world,false},{preview,v.world,true},{mini,v.mini,false},{guidance,v.mini,true}}) do
   e[1]:ClearAllPoints();e[1]:SetPoint('TOPLEFT',e[2],'TOPLEFT',left+(e[3] and not v.stacked and 454 or 0),e[3] and v.stacked and -296 or 0)
  end
 end
 function v.Refresh()
  local s=A.Resources.Settings(A.db.settings);local worldPage=v.page=='world'
  if worldPage then v.world:Show();v.mini:Hide() else v.world:Hide();v.mini:Show() end
  S.Selected(U.controls.displayWorld,worldPage);S.Selected(U.controls.displayMini,not worldPage)
  for key,value in pairs({nodeWorld=s.world,nodeMini=s.mini,nodeIcon=s.icon,nodeGroupWorld=s.groupWorld,nodeGroupMini=s.groupMini,nodeRouteLine=s.routeLines}) do U.controls[key]:SetChecked(value) end
  for key,value in pairs({nodeOutline=s.outline,nodeOutlineSize=s.outlineSize,nodeIconSize=s.iconSize,nodeWorldIconSize=s.worldIconSize,nodeDistance=s.hideDistance}) do U.controls[key]:SetValue(value) end
  U.syncingOptions=true
  for _,e in ipairs({{'nodeWorldOpacity','worldIconOpacity','World-map icons'},{'nodeMiniIconOpacity','miniIconOpacity','Minimap icons'},{'nodeOutlineOpacity','miniOutlineOpacity','Minimap outlines'},{'nodeRouteOpacity','routeOpacity','Route overlay'}}) do
   local value=math.floor(s[e[2]]*100+.5);U.controls[e[1]]:SetValue(value);v.opacityLabels[e[1]]:SetText(e[3]..': '..value..'%')
  end
  U.syncingOptions=false
  for _,key in ipairs({'nodeGroupWorld','nodeWorldIconSize','nodeWorldOpacity'}) do U.controls[key]:SetEnabled(s.world) end
  for _,key in ipairs({'nodeGroupMini','nodeOutline','nodeIconSize','nodeDistance','nodeMiniIconOpacity'}) do U.controls[key]:SetEnabled(s.mini) end
  U.controls.nodeIcon:SetEnabled(s.mini and s.outline~='none')
  U.controls.nodeOutlineSize:SetEnabled(s.mini and s.outline~='none');U.controls.nodeOutlineOpacity:SetEnabled(s.mini and s.outline~='none')
  U.controls.nodeRouteOpacity:SetEnabled(s.routeLines)
  for i,icon in ipairs(v.worldExamples) do
   icon:SetSize(s.worldIconSize+8,s.worldIconSize+8);icon:SetAlpha(s.worldIconOpacity)
   if s.world and (i==1 or not s.groupWorld) then icon:Show() else icon:Hide() end
  end
  v.worldExamples[1]:SetTexture(s.groupWorld and S.media..'Icon' or A.Resources.Icon({kind='herb',materialID='gm:herb:402'}))
  if s.world and s.groupWorld then v.worldCount:Show();v.worldCount:SetAlpha(s.worldIconOpacity) else v.worldCount:Hide() end
  v.miniIcon:SetAlpha(s.miniIconOpacity);v.miniCount:SetAlpha(s.miniIconOpacity)
  if s.mini and s.icon then v.miniIcon:Show() else v.miniIcon:Hide() end
  if s.mini and s.icon and s.groupMini then v.miniCount:Show() else v.miniCount:Hide() end
  if s.mini and s.outline~='none' then v.miniOutline:Show() else v.miniOutline:Hide() end
  v.miniOutline:SetTexture(S.media..(s.outline=='square' and 'NodeSquare' or 'NodeRing'));v.miniOutline:SetVertexColor(.3,.85,.35);v.miniOutline:SetAlpha(s.miniOutlineOpacity)
  if U.tab=='nodes' then U.zone:SetText('Node display  -  '..(worldPage and 'World map' or 'Minimap')) end
 end
 U.nodeOpacityLabels=v.opacityLabels
 return v
end
