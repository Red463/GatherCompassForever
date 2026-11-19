local _,A=...
local V={};A.PreferencesView=V
function V.New(parent,U)
 local S=A.Skin;local v={};local scroll=A.ScrollPanel.New(parent);v.scroller=scroll;v.frame=scroll.frame;local body=scroll.body
 v.frame:SetPoint('TOPLEFT',parent,'TOPLEFT',20,-19)
 local function place(o,p,x,y,w,h) o:ClearAllPoints();o:SetPoint('TOPLEFT',p,'TOPLEFT',x,-y);o:SetSize(w,h);return o end
 local function label(p,text,x,y,w,h,size,color) return place(S.Label(p,text,size or 12,color or S.text),p,x,y,w,h) end
 local function button(p,key,text,fn) local b=S.Button(p,text,fn or U.actions[key]);U.controls[key]=b;return b end
 local function check(p,key,text,fn)
  local b=S.Check(p,text,fn or U.actions[key]);b.label:SetWidth(290);b:SetHitRectInsets(0,-294,0,0);U.controls[key]=b;return b
 end
 label(body,'Preferences',0,0,600,26,18,S.gold)
 v.subtitle=label(body,'Set how the guide behaves and how your window appears.',0,32,800,20,12,S.muted)
 v.navigation=S.Panel(body);v.arrow=S.Panel(body);v.panel=S.Panel(body)
 label(v.navigation,'Navigation',18,12,400,24,16,S.gold)
 v.arrivalLabel=label(v.navigation,'Advance to next waypoint within',18,44,500,24,13)
 U.controls.arrival=S.Slider(v.navigation,5,40,5,U.actions.arrivalValue)
 U.arrivalValue=label(v.navigation,'',440,76,110,24,13,S.gold)
 v.arrivalHelp=label(v.navigation,'',18,116,800,40,12,S.text);v.arrivalHelp:SetWordWrap(true)
 v.arrivalNote=label(v.navigation,'Larger distances advance sooner; smaller distances require a closer approach.',18,164,800,20,11,S.muted)
 S.Hint(U.controls.arrival,'When the guide advances','The distance is a radius around the current waypoint, not a gathering range. Changes apply immediately. Guidance waits while you gather; overlapping stops require movement to prevent repeatedly advancing while stationary.')
 label(v.arrow,'Guide arrow',18,12,320,24,16,S.gold)
 label(v.arrow,'Arrow size',18,46,200,22,13)
 U.controls.arrowScale=S.Slider(v.arrow,.6,2,.1,U.actions.arrowScaleValue,function(value) return math.floor(value*100+.5)..'%' end)
 U.arrowScaleValue=label(v.arrow,'',320,76,90,24,13,S.gold)
 check(v.arrow,'arrowProgress','Show route step and lap');check(v.arrow,'arrowNodeName','Show next node name')
 button(v.arrow,'resetArrow','Reset arrow position & size')
 v.arrowHelp=label(v.arrow,'Drag the arrow to move it. Click it to reopen the panel.',18,224,380,32,11,S.muted);v.arrowHelp:SetWordWrap(true)
 label(v.panel,'Panel & minimap',18,12,320,24,16,S.gold)
 check(v.panel,'minimapButton','Show minimap button')
 label(v.panel,'Panel size',18,82,160,22,13)
 local sizes={};for _,preset in ipairs(A.PanelWindow.Presets) do sizes[#sizes+1]={value=preset.id,label=preset.label} end
 U.controls.panelPreset=S.Dropdown(v.panel,sizes,function(id) U.window:SetPreset(id) end)
 U.panelSizeValue=label(v.panel,'',18,140,380,24,12,S.muted)
 button(v.panel,'resetPanel','Reset panel size',function() U.window:Reset() end)
 v.panelHelp=label(v.panel,'Choose a fixed layout. Text and controls keep their normal size.',18,224,380,42,11,S.muted);v.panelHelp:SetWordWrap(true)
 S.Hint(U.controls.arrowProgress,'Arrow progress','Show the waypoint number and current lap. Laps start at 1.')
 S.Hint(U.controls.arrowNodeName,'Next node name','Show the resource at the next gathering stop below the distance.')
 S.Hint(U.controls.minimapButton,'Minimap launcher','Click the compass button to open the panel; drag it around the minimap. Use /gatherly when it is hidden.')
 function v.Layout(width,height)
  local w,h=width-40,height-19;local stacked=w-20<760;local content=stacked and 828 or 550
  local available=scroll:Layout(w,h,content);v.subtitle:SetWidth(available)
  place(v.navigation,body,0,62,available,192)
  local cw=stacked and available or (available-16)/2
  place(v.arrow,body,0,270,cw,280);place(v.panel,body,stacked and 0 or cw+16,stacked and 546 or 270,cw,280)
  local sliderWidth=math.min(400,available-160);place(U.controls.arrival,v.navigation,18,82,sliderWidth,18);place(U.arrivalValue,v.navigation,sliderWidth+40,76,110,24)
  v.arrivalHelp:SetWidth(available-36);v.arrivalNote:SetWidth(available-36)
  place(U.controls.arrowScale,v.arrow,18,82,cw-130,18);place(U.arrowScaleValue,v.arrow,cw-92,76,76,24)
  place(U.controls.arrowProgress,v.arrow,16,118,24,24);place(U.controls.arrowNodeName,v.arrow,16,148,24,24)
  place(U.controls.resetArrow,v.arrow,18,190,cw-36,26);v.arrowHelp:SetWidth(cw-36)
  place(U.controls.minimapButton,v.panel,16,46,24,24);U.panelSizeValue:SetWidth(cw-36)
  place(U.controls.panelPreset,v.panel,18,108,cw-36,26)
  place(U.controls.resetPanel,v.panel,18,180,cw-36,26);v.panelHelp:SetWidth(cw-36)
 end
 function v.Refresh()
  U.syncingOptions=true;U.controls.arrival:SetValue(A.db.settings.arrival or 15);U.controls.arrowScale:SetValue(tonumber(A.db.settings.arrowScale) or 1);U.syncingOptions=false
  local arrival=A.db.settings.arrival or 15;U.arrivalValue:SetText(arrival..' yards')
  v.arrivalHelp:SetText('At '..arrival..' yards, entering a '..arrival..'-yard radius around the target advances the guide. You do not have to gather the node. Changes apply immediately.')
  U.arrowScaleValue:SetText(math.floor((tonumber(A.db.settings.arrowScale) or 1)*100+.5)..'%')
  U.controls.arrowProgress:SetChecked(A.db.settings.arrowProgress~=false);U.controls.arrowNodeName:SetChecked(A.db.settings.arrowNodeName==true);U.controls.minimapButton:SetChecked(A.db.settings.minimapButton~=false)
  if U.window.geometry then
   local g=U.window.geometry;U.controls.panelPreset:SetValue(g.preset)
   U.panelSizeValue:SetText(g.label..': '..g.width..' x '..g.height..' UI units')
   v.panelHelp:SetText(g.preset~=g.effectivePreset and ('Using '..g.label..' to fit your screen. Your chosen size returns when it fits.') or g.scale<1 and 'Scaled to fit your screen. Your chosen size is saved.' or 'Choose a fixed layout. Text and controls keep their normal size.')
  end
 end
 return v
end
