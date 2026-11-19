local _, A = ...
local V={};A.WelcomeView=V
local S=A.Skin
local function place(f,parent,x,y,w,h) f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);f:SetSize(w,h);return f end
local function label(parent,text,x,y,w,h,size,color,heading)
 local f=place(S.Label(parent,text,size or 12,color or S.text,heading),parent,x,y,w,h);f:SetWordWrap(true);return f
end
function V.New(parent,U)
 local view={cards={}}
 local f=place(CreateFrame('Frame',nil,parent),parent,20,19,896,395);view.frame=f
 place(S.Image(f,'Icon',88,88),f,12,4,88,88)
 label(f,'Welcome to Gather Compass Forever',120,7,760,30,21,S.gold,true)
 label(f,'Remember your discoveries. Choose what to farm. Follow your next trail.',120,43,760,24,13,S.text)
 view.summary=label(f,'',120,73,760,22,11,S.muted)
 local steps={
  {'1. Add node locations','Gather herbs or ore to remember successful discoveries, or import known locations from installed GatherMate2 data. Import covers all zones, wherever you are.'},
  {'2. Choose what to farm','Tick your node sources, Herbs or Ore, and the materials you want. These selections filter both maps and generated routes. Gatherable includes grey resources; Skill-ups selects skill-up materials once.'},
  {'3. Follow your route','Use Generate & start for quick guidance, or Generate & review to inspect the map and remove nodes. Choose lines or a heatmap corridor. Click the gold arrow to return.'},
 }
 for i,step in ipairs(steps) do
  local card=place(S.Panel(f),f,(i-1)*304,118,288,192);view.cards[i]=card
  label(card,step[1],14,13,260,25,15,S.gold,true)
  label(card,step[2],14,47,260,94,12,S.muted)
 end
 local import=S.Button(view.cards[1],'Import node data',function()
  if A.importJob then return end
  U.actions.import();U.Refresh()
 end,'primary');place(import,view.cards[1],14,151,260,26);U.controls.import=import
 S.Hint(import,'Import all node data','Load herb and ore locations for every supported zone from installed GatherMate2_Data, with GatherMate2 observations as a fallback. Personal discoveries stay separate.')
 view.resources=place(S.Button(view.cards[2],'Browse resources',function() U.SetTab('resources') end,'subtle'),view.cards[2],14,151,260,26)
 view.routes=place(S.Button(view.cards[3],'Open routes',U.OpenRoutes,'subtle'),view.cards[3],14,151,260,26)
 label(f,'Import status',2,322,892,20,13,S.gold)
 view.status=label(f,'',2,346,892,46,12,S.muted)
 function view.Refresh(player)
  local index=A.Atlas.Index(A.db);local known=0;for _,entry in ipairs(index.resources) do known=known+#entry.nodes end
  view.summary:SetText(known..' known locations across '..#index.zones..' zones. Imported markers are possible spawns, not live availability.')
  import:SetEnabled(not A.importJob);import:SetText(A.importJob and 'Importing...' or 'Import node data')
  view.status:SetText(tostring(A.status or 'Ready. Import an installed data pack, or start gathering to build your own node history.'):gsub('|','||'))
  U.zone:SetText(U.ZoneName(player and player.mapID)..'  -  Welcome')
 end
 return view
end
