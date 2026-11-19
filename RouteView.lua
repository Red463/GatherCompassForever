local _,A=...
local V={};A.RouteView=V
function V.New(parent,U)
 local S=A.Skin;local v={}
 local function place(f,x,y,w,h) f:SetPoint('TOPLEFT',v.frame,'TOPLEFT',x,-y);f:SetSize(w,h);return f end
 v.frame=CreateFrame('Frame',nil,parent);v.frame:SetPoint('TOPLEFT',parent,'TOPLEFT',16,-4);v.frame:SetSize(710,395)
 local function label(text,x,y,w,h,size,color) return place(S.Label(v.frame,text,size or 12,color or S.text),x,y,w,h) end
 local function button(key,text,x,y,w,fn,style) local b=place(S.Button(v.frame,text,fn or U.actions[key],style),x,y,w,26);U.controls[key]=b;return b end
 label('Your farming corridor',0,0,310,27,18,S.gold)
 v.primary=button('generateStart','Generate & start',374,0,162,nil,'primary')
 button('generateReview','Generate & review',544,0,166,nil,'subtle')
 v.info=label('',0,33,710,32,11,S.muted);v.info:SetWordWrap(true)
 local markerOption=S.Check(v.frame,'Only show route target nodes during an active route',function()
  A.db.settings.routeMarkerOverride=not A.db.settings.routeMarkerOverride;U.Refresh()
  if A.Map then A.Map.SetNodeFocus(nil);A.Map.Refresh(A.db,U.DisplayRoute(),A.follower) end
 end);U.controls.markerRouteOverride=markerOption
 local miniOption=S.Check(v.frame,'Show route controls',function()
  A.db.settings.routeControls=A.db.settings.routeControls==false;U.Refresh()
 end);U.controls.miniRouteControls=miniOption
 S.Hint(miniOption,'Show route controls','Automatically show a movable panel with Stop route, Open panel and Skip next node while following a route. Turning this off hides the panel without stopping guidance.')
 S.Hint(markerOption,'Map markers during a route','While guidance is active, including paused guidance, both maps show nodes matching the sources, gathering types and materials saved with that route. Your normal map-marker selections return when the route stops or finishes. Route lines and the arrow are unaffected.')
 U.controls.routeStyle=place(S.Dropdown(v.frame,{{value='lines',label='Route lines'},{value='heatmap',label='Heatmap corridor'}},U.actions.routeStyle),538,69,172,26)
 v.selection=label('Select a node on the map to remove it from this route.',0,74,528,20,11,S.muted)
 v.sketch=A.RouteSketch.New(v.frame);U.routeSketch=v.sketch;place(v.sketch.frame,0,102,710,276)
 button('removeNode','Remove node',0,382,128)
 button('undoNode','Undo removal',136,382,128)
 button('map','World map',574,382,136)
 function v.Layout(width,height)
  local w,h=width-32,height-8;v.frame:SetSize(w,h);v.narrow=w<710
  local function move(f,x,y,fw,fh) f:ClearAllPoints();f:SetPoint('TOPLEFT',v.frame,'TOPLEFT',x,-y);f:SetSize(fw,fh) end
  local top=v.narrow and 36 or 0
  move(U.controls.generateStart,w-336,top,162,26);move(U.controls.generateReview,w-166,top,166,26)
  move(v.info,0,33+top,w,32)
  move(markerOption,0,68+top,24,24);markerOption.label:SetSize(w-268,24);markerOption:SetHitRectInsets(0,-(w-264),0,0)
  move(miniOption,w-222,68+top,24,24);miniOption.label:SetSize(194,24);miniOption:SetHitRectInsets(0,-194,0,0)
  move(U.controls.routeStyle,w-172,97+top,172,26)
  move(v.selection,0,102+top,w-182,20)
  move(v.sketch.frame,0,130+top,w,math.max(80,h-162-top))
  for _,e in ipairs({{U.controls.removeNode,0,128},{U.controls.undoNode,136,128},{U.controls.map,w-136,136}}) do move(e[1],e[2],h-26,e[3],26) end
 end
 function v.Refresh()
  miniOption:SetChecked(A.db.settings.routeControls~=false)
  markerOption:SetChecked(A.db.settings.routeMarkerOverride==true)
  local plan=A.plan;local route=plan and plan.route;local nodes=U.SelectedNodes()
  local text=plan and plan.message or 'Tick the materials you want, then generate a nearby route. No save step is needed.'
  if plan and not plan:Matches(U.Filter()) then text='Selections changed. Generate again to use them. '..(text or '') end
  if route and route.corridor then
   local zoom=A.Client.MinimapZoom()
   local radius=A.Client.MinimapRadius()
   if (not zoom or zoom==0) and A.Store.Number(radius) and radius<route.coverageRadius then
    text=text..string.format('\nMinimap range is reduced. Saved coverage stays at %.0f yards.',route.coverageRadius)
   else text=text..'\n'..(zoom and zoom>0 and 'Zoom minimap fully out. ' or 'Use a fully zoomed-out minimap. ')..string.format('Nodes within %.0f yards of the path count as covered.',route.coverageRadius) end
  elseif not plan then text=text..'\nZoom your minimap fully out before generating a corridor.' end
  v.info:SetText(text or '')
  local selected=plan and plan.byKey and plan.byKey[plan.selected]
  local filter=U.Filter();local viewKey=A.FarmingSession.Signature(filter)..':'..tostring(plan and plan.revision)
  if v.plan~=plan or v.nodesKey~=viewKey then
   v.nodes={};for _,n in ipairs(plan and plan.candidates or nodes) do if A.Selection.Matches(n,filter) then v.nodes[#v.nodes+1]=n end end
   v.plan=plan;v.nodesKey=viewKey
  end
  if selected and not A.Selection.Matches(selected,filter) then selected=nil;plan.selected=nil end
  v.selection:SetText(selected and ((selected.name or 'Node')..string.format('  /  %.1f, %.1f',selected.x*100,selected.y*100)) or 'Select a node to remove it. Scroll to zoom; right-drag to pan.')
  U.controls.removeNode:SetEnabled(selected~=nil);U.controls.undoNode:SetEnabled(plan~=nil and #plan.undo>0)
  U.controls.generateStart:SetEnabled(#nodes>0);U.controls.generateReview:SetEnabled(#nodes>0)
  U.controls.routeStyle:SetValue(A.db.settings.routeStyle=='heatmap' and 'heatmap' or 'lines')
  local f=A.follower;local following=f and f.session==plan and (f.status=='running' or f.status=='paused' or f.status=='suspended')
  local visible=plan and (plan.review or following)
  v.sketch:Draw(visible and route or nil,nil,{plan=plan,nodes=plan and v.nodes or nodes,viewKey=viewKey,selected=plan and plan.selected,onSelect=U.actions.selectNode,style=A.db.settings.routeStyle,mapID=plan and plan.mapID or (A.Client.Position() or {}).mapID})
 end
 return v
end
