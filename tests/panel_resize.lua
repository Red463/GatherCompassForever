local function setup()
 dofile('tests/wow.lua');fakeUI();UIParent:SetSize(1920,1080)
 local A={};module('Store',A);module('Client',A);module('Planner',A);module('Follower',A);moduleUI(A);A.db=A.Store.Open()
 A.Client.Position=function() return point(.3) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.Client.Probe=function() return {loot=true,facing=true,distance=true,minimap=true} end
 assert(A.UI.Build());A.UI.OpenRoutes();return A
end

test('fixed presets default to Standard and migrate old dimensions once without losing position',function()
 local A={};module('Store',A);module('PanelWindow',A);local P=A.PanelWindow
 local settings={};local g=P.Resolve(settings,1920,1080,false);eq(g.width,1100);eq(g.height,780);eq(g.scale,1);eq(settings.panel.preset,'standard')
 for _,v in ipairs({{960,624,'small'},{1400,900,'large'},{1100,750,'standard'}}) do
  settings.panel={width=v[1],height=v[2],x=.8,y=.2};g=P.Resolve(settings,1920,1080,false)
  eq(settings.panel.preset,v[3]);eq(settings.panel.width,nil);eq(settings.panel.height,nil);eq(settings.panel.x,.8);eq(settings.panel.y,.2)
 end
 settings.panel={width=0/0,height=math.huge,preset='invalid',x='bad',y=-20};g=P.Resolve(settings,1920,1080,false)
 eq(g.width,1100);eq(g.height,780);assert(g.left>=12)
end)

test('screen fitting selects a smaller fixed layout without overwriting the preferred preset',function()
 local A={};module('Store',A);module('PanelWindow',A);local P=A.PanelWindow;local s={panel={preset='large',x=1,y=0}}
 local g=P.Resolve(s,1200,850,false);eq(g.width,1100);eq(g.height,780);eq(g.effectivePreset,'standard');eq(g.scale,1);eq(s.panel.preset,'large')
 g=P.Resolve(s,1024,768,false);eq(g.width,960);eq(g.height,680);eq(g.effectivePreset,'small');eq(g.scale,1);assert(g.left>=12 and g.top<=756)
 g=P.Resolve(s,800,500,false);eq(g.width,960);eq(g.height,680);assert(g.scale<1);eq(s.panel.preset,'large')
 g=P.Resolve(s,1920,1080,false);eq(g.width,1240);eq(g.height,880);eq(g.effectivePreset,'large')
end)

test('Preferences exposes only fixed panel size choices and no free resize grip',function()
 local A=setup();local U=A.UI;eq(U.window.grip,nil);eq(U.window.Resize,nil)
 U.SetTab('settings');local choice=U.controls.panelPreset;assert(choice and choice.isDropdown);eq(choice:GetValue(),'standard')
 A.db.settings.arrowScale=1.7;choice:SelectValue('large');eq(U.frame:GetWidth(),1240);eq(U.frame:GetHeight(),880);eq(A.db.settings.panel.preset,'large')
 eq(A.db.settings.arrowScale,1.7);eq(U.controls.generateStart:GetHeight(),26);eq(U.controls.generateStart.label.fontSize,12)
 U.SetCompact(true);eq(U.frame:GetWidth(),730);eq(U.frame:GetHeight(),98);U.SetCompact(false);eq(U.frame:GetWidth(),1240)
 U.controls.resetPanel.scripts.OnClick();eq(A.db.settings.panel.preset,'standard');eq(U.frame:GetHeight(),780)
 eq(U.window:SetPreset('invalid'),false);eq(A.db.settings.panel.preset,'standard')
end)

test('fitted Preferences explains the effective layout and display changes restore the saved choice',function()
 local A=setup();local U=A.UI;U.window:SetPreset('large');UIParent:SetSize(1024,768);U.frame.scripts.OnEvent(U.frame,'DISPLAY_SIZE_CHANGED');U.SetTab('settings')
 eq(U.frame:GetWidth(),960);eq(U.controls.panelPreset:GetValue(),'large');assert(U.panelSizeValue:GetText():find('Small',1,true));assert(U.preferencesView.panelHelp:GetText():find('fit',1,true))
 UIParent:SetSize(1920,1080);U.frame.scripts.OnEvent(U.frame,'UI_SCALE_CHANGED');eq(U.frame:GetWidth(),1240)
end)

test('every preset keeps Routes controls inside the layout and the map proportional',function()
 local A=setup();local U=A.UI
 C_Map={GetMapArtID=function() return 1 end,GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=667,tileWidth=1000,tileHeight=667}} end,GetMapArtLayerTextures=function() return {123} end}
 local route={mapID=1,width=1000,height=667,points={point(.3),point(.5)}}
 for _,id in ipairs({'small','standard','large'}) do
  U.window:SetPreset(id);local v=U.routeView;local w,h=v.frame:GetWidth(),v.frame:GetHeight()
  assert(U.routeSketch.frame:GetWidth()>=710);assert(U.routeSketch.frame:GetHeight()>=320)
  for _,key in ipairs({'generateStart','generateReview','routeStyle','removeNode','undoNode','map'}) do
   local f=U.controls[key];assert(f.point[4]>=0 and f.point[4]+f:GetWidth()<=w);assert(-f.point[5]+f:GetHeight()<=h)
  end
  U.routeSketch:Draw(route);local b,mw,mh=U.routeSketch:Bounds();near((mw/(b.right-b.left))/(mh/(b.bottom-b.top)),1000/667)
  local x,y=U.routeSketch.Project(route.points[1]);near(x,(.3-b.left)/(b.right-b.left)*mw);near(y,-(.5-b.top)/(b.bottom-b.top)*mh)
  eq(U.frame.scale,1);eq(U.controls.generateStart.label.fontSize,12)
 end
end)

test('switching presets preserves plan follower map camera selection and independent filters',function()
 local A=setup();local U=A.UI
 for i=1,8 do A.Store.Observe(A.db,{mapID=1,x=.3+i*.03,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'}) end
 U.actions.generateReview();local plan=A.plan;U.actions.start();local follower=A.follower;U.OpenRoutes()
 U.routeSketch:Zoom(1);U.routeSketch:Pan(12,4);local zoom,cx,cy=U.routeSketch.zoom,U.routeSketch.cx,U.routeSketch.cy
 local materials=A.db.settings.materials;local markers=A.db.settings.markerFilters
 for _,id in ipairs({'small','large','standard'}) do U.window:SetPreset(id);eq(A.plan,plan);eq(A.follower,follower);eq(U.routeSketch.zoom,zoom);eq(U.routeSketch.cx,cx);eq(U.routeSketch.cy,cy);eq(follower.status,'running');eq(A.db.settings.materials,materials);eq(A.db.settings.markerFilters,markers) end
end)

test('all tabs and custom Codex resources remain accessible in each preset',function()
 local A=setup();local U=A.UI
 for i=1,80 do A.Store.Observe(A.db,{mapID=1,x=.2+i*.001,y=.5,kind='herb',materialID='node:herb:Custom '..i,name='Custom '..i,source='confirmed'}) end
 for _,id in ipairs({'small','standard','large'}) do
  U.window:SetPreset(id)
  for _,tab in ipairs({'welcome','routes','codex','nodes','settings'}) do U.SetTab(tab);assert(U.body:IsVisible());assert(U.content:GetWidth()>0) end
  U.SetTab('codex');local v=U.codexView;local seen={}
  for offset=0,v.gridList.scroller.maximum+v.gridList.height,v.gridList.height do v.gridList:SetOffset(offset);for _,b in ipairs(v.tiles) do if b.item and b:IsVisible() then seen[b.item.id]=true end end end
  local count=0;for _ in pairs(seen) do count=count+1 end;eq(count,#v.model.items)
  v.Open(v.model.items[1].id);assert(v.zoneTotals.point[4]+v.zoneTotals:GetWidth()<=v.zones:GetWidth());v.Back()
 end
end)

test('panel movement and fixed-size changes preserve the saved position',function()
 local A=setup();local U=A.UI;local resets=0;U.frame.ClearAllPoints=function() resets=resets+1 end
 U.header.scripts.OnDragStart(U.header);U.Refresh();eq(resets,0)
 U.frame.GetCenter=function() return 650,500 end;U.header.scripts.OnDragStop(U.header)
 near(A.db.settings.panel.x,650/1920);near(A.db.settings.panel.y,500/1080)
 U.window:SetPreset('small');near(A.db.settings.panel.x,650/1920);near(A.db.settings.panel.y,500/1080)
end)

test('changing preset closes stale dropdowns and grouped marker choosers',function()
 local A=setup();local U=A.UI;U.SetTab('nodes');U.nodeDisplayView.SetPage('world');local control=U.controls.nodeWorldIconSize
 control.scripts.OnClick(control);eq(A.Skin.dropdownOwner,control);U.window:SetPreset('small');eq(A.Skin.dropdownOwner,nil)
 U.routeSketch.picker.frame:Show();U.window:SetPreset('large');eq(U.routeSketch.picker.frame:IsShown(),false)
end)
