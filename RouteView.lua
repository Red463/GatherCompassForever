local _,A=...
local V={};A.RouteView=V
function V.New(parent,U)
 local S=A.Skin;local v={}
 local function place(f,x,y,w,h) f:SetPoint('TOPLEFT',v.frame,'TOPLEFT',x,-y);f:SetSize(w,h);return f end
 v.frame=CreateFrame('Frame',nil,parent);v.frame:SetPoint('TOPLEFT',parent,'TOPLEFT',16,-12);v.frame:SetSize(710,395)
 local function label(text,x,y,w,h,size,color) return place(S.Label(v.frame,text,size or 12,color or S.text),x,y,w,h) end
 local function button(key,text,x,y,w,fn,style) local b=place(S.Button(v.frame,text,fn or U.actions[key],style),x,y,w,26);U.controls[key]=b;return b end
 label('Your farming corridor',0,0,310,27,18,S.gold)
 v.primary=button('generateStart','Generate & start',374,0,162,nil,'primary')
 button('generateReview','Generate & review',544,0,166,nil,'subtle')
 v.info=label('',0,33,710,32,11,S.muted);v.info:SetWordWrap(true)
 U.controls.routeStyle=place(S.Dropdown(v.frame,{{value='lines',label='Route lines'},{value='heatmap',label='Heatmap corridor'}},U.actions.routeStyle),538,69,172,26)
 v.selection=label('Select a node on the map to remove it from this route.',0,74,528,20,11,S.muted)
 v.sketch=A.RouteSketch.New(v.frame);U.routeSketch=v.sketch;place(v.sketch.frame,0,102,710,276)
 button('removeNode','Remove node',0,382,128)
 button('undoNode','Undo removal',136,382,128)
 button('map','World map',574,382,136)
 function v.Refresh()
  local plan=A.plan;local route=plan and plan.route;local nodes=U.SelectedNodes()
  local text=plan and plan.message or 'Tick the materials you want, then generate a nearby route. No save step is needed.'
  if plan and not plan:Matches(U.Filter()) then text='Selections changed. Generate again to use them. '..(text or '') end
  v.info:SetText(text or '')
  local selected
  if plan then for _,n in ipairs(plan.candidates) do if A.FarmingSession.Key(n)==plan.selected then selected=n;break end end end
  v.selection:SetText(selected and ((selected.name or 'Node')..string.format('  /  %.1f, %.1f',selected.x*100,selected.y*100)) or 'Select a node to remove it. Scroll to zoom; right-drag to pan.')
  U.controls.removeNode:SetEnabled(selected~=nil);U.controls.undoNode:SetEnabled(plan~=nil and #plan.undo>0)
  U.controls.generateStart:SetEnabled(#nodes>0);U.controls.generateReview:SetEnabled(#nodes>0)
  U.controls.routeStyle:SetValue(A.db.settings.routeStyle=='heatmap' and 'heatmap' or 'lines')
  v.sketch:Draw(route,nil,{plan=plan,nodes=plan and plan.candidates or nodes,selected=plan and plan.selected,onSelect=U.actions.selectNode,style=A.db.settings.routeStyle,mapID=plan and plan.mapID or (A.Client.Position() or {}).mapID})
 end
 return v
end
