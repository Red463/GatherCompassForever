local _, A = ...
local V={};A.WelcomeView=V
local S=A.Skin
local function place(f,parent,x,y,w,h) f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);f:SetSize(w,h);return f end
local function label(parent,text,x,y,w,h,size,color,heading)
 local f=place(S.Label(parent,text,size or 12,color or S.text,heading),parent,x,y,w,h);f:SetWordWrap(true);return f
end
function V.New(parent,U)
 local view={cards={}}
 local scroller=A.ScrollPanel.New(parent);view.scroller=scroller;view.frame=scroller.frame
 place(view.frame,parent,20,19,896,395);local f=scroller.body;f:SetSize(896,395)
 place(S.Image(f,'Icon',88,88),f,12,4,88,88)
 view.title=label(f,'Welcome to Gather Compass Forever',120,7,760,30,21,S.gold,true)
 view.subtitle=label(f,'Remember your discoveries. Choose what to farm. Follow your next trail.',120,43,760,24,13,S.text)
 view.summary=label(f,'',120,73,760,22,11,S.muted)
 local steps={
  {'1. Add node locations','Gather herbs or ore to remember successful discoveries, or import known locations from installed GatherMate2 data. Import covers all zones, wherever you are.'},
  {'2. Choose what to farm','In Routes, tick the sources, gathering types and materials for your route. Everyday map markers have separate choices in Node display > Visible nodes.'},
  {'3. Follow your route','Use Generate & start for quick guidance, or Generate & review to inspect the map and remove nodes. Choose lines or a heatmap corridor. Click the gold arrow to return.'},
 }
 for i,step in ipairs(steps) do
  local card=place(S.Panel(f),f,(i-1)*304,118,288,192);view.cards[i]=card
  card.title=label(card,step[1],14,13,260,25,15,S.gold,true)
  card.description=label(card,step[2],14,47,260,94,12,S.muted)
 end
 local import=S.Button(view.cards[1],'Import node data',function()
  if A.importJob then return end
  U.actions.import();U.Refresh()
 end,'primary');place(import,view.cards[1],14,151,260,26);U.controls.import=import
 S.Hint(import,'Import all node data','Load herb and ore locations for every supported zone from installed GatherMate2_Data, with GatherMate2 observations as a fallback. Personal discoveries stay separate.')
 view.resources=place(S.Button(view.cards[2],'Choose materials',U.OpenRoutes,'subtle'),view.cards[2],14,151,260,26)
 view.routes=place(S.Button(view.cards[3],'Open routes',U.OpenRoutes,'subtle'),view.cards[3],14,151,260,26)
 view.statusTitle=label(f,'Import status',2,322,892,20,13,S.gold)
 view.status=label(f,'',2,346,892,46,12,S.muted)
 function view.Layout(width,height)
  local w,h=width-40,height-19;local narrow=w<896;local cardHeight=narrow and 228 or 192
  local content=118+cardHeight+82;local available=scroller:Layout(w,h,content)
  local cardWidth=math.min(320,(available-32)/3);local left=math.max(0,(available-(cardWidth*3+32))/2)
  for _,t in ipairs({view.title,view.subtitle,view.summary}) do t:SetWidth(math.min(760,available-120)) end
  for i,card in ipairs(view.cards) do
   card:ClearAllPoints();place(card,f,left+(i-1)*(cardWidth+16),118,cardWidth,cardHeight)
   card.title:SetWidth(cardWidth-28);card.description:SetSize(cardWidth-28,cardHeight-98)
   local action=({import,view.resources,view.routes})[i];action:ClearAllPoints();place(action,card,14,cardHeight-41,cardWidth-28,26)
  end
  view.statusTitle:ClearAllPoints();place(view.statusTitle,f,2,118+cardHeight+12,available-4,20)
  view.status:ClearAllPoints();place(view.status,f,2,118+cardHeight+36,available-4,46)
 end
 function view.Refresh(player)
  local index=A.Atlas.Index(A.db);local known=0;for _,entry in ipairs(index.resources) do known=known+#entry.nodes end
  view.summary:SetText(known..' known locations across '..#index.zones..' zones. Imported markers are possible spawns, not live availability.')
  import:SetEnabled(not A.importJob);import:SetText(A.importJob and 'Importing...' or 'Import node data')
  view.status:SetText(tostring(A.status or 'Ready. Import an installed data pack, or start gathering to build your own node history.'):gsub('|','||'))
  U.zone:SetText(U.ZoneName(player and player.mapID)..'  -  Welcome')
 end
 return view
end
