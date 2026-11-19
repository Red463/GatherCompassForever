local function setup()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Editor','Planner','Follower','FarmingSession'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 for i=1,8 do A.Store.Observe(A.db,{mapID=1,x=.1+i*.04,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'}) end
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end

test('mini panel colour choice applies immediately without changing the route and closes with controls',function()
 local A,U=setup();U.actions.generateStart();local C=A.RouteControls;local f,plan=A.follower,A.plan
 local redraw=0;A.Map={Refresh=function(db,route,follower)
  redraw=redraw+1;eq(A.Resources.Settings(db.settings).miniHeatColour,'cyan');eq(route,f.route);eq(follower,f)
 end}
 eq(C.colour:GetValue(),'amber');C.colour.scripts.OnClick(C.colour);eq(A.Skin.dropdownOwner,C.colour)
 C.colour:SelectValue('cyan');eq(redraw,1);eq(A.db.settings.nodeDisplay.miniHeatColour,'cyan');eq(C.colour:GetValue(),'cyan')
 eq(U.frame:IsShown(),false);eq(A.follower,f);eq(A.plan,plan);eq(A.Skin.dropdownOwner,nil)
 A.db=A.Store.Open(A.Store.Copy(A.db));C.Update(f);eq(C.colour:GetValue(),'cyan')
 eq(C.swatch.color[1],.1);eq(C.swatch.color[2],.9);eq(C.swatch.color[3],1)
 C.colour.scripts.OnClick(C.colour);assert(A.Skin.dropdownMenu:IsShown());A.db.settings.routeControls=false;U.Refresh()
 eq(A.Skin.dropdownOwner,nil);eq(A.Skin.dropdownMenu:IsShown(),false);eq(A.follower,f)
end)

test('route controls appear on start, survive main panel hiding and use current route actions',function()
 local A,U=setup();U.actions.generateReview();eq(A.RouteControls.frame,nil)
 U.actions.start();local C=A.RouteControls;assert(C.frame:IsShown());eq(U.frame:IsShown(),false)
 local f=A.follower;local index=f.index;C.skip.scripts.OnClick();assert(f.index~=index)
 C.open.scripts.OnClick();assert(U.frame:IsShown());eq(U.tab,'routes');eq(A.follower,f)
 U.actions.generateStart();local replacement=A.follower;assert(replacement~=f)
 index=replacement.index;C.skip.scripts.OnClick();assert(replacement.index~=index)
 C.stop.scripts.OnClick();eq(A.follower,nil);eq(C.frame:IsShown(),false)
end)

test('Routes checkbox disables controls without changing guidance and restores on reenable',function()
 local A,U=setup();U.actions.generateStart();U.OpenRoutes();local f,plan=A.follower,A.plan
 local check=U.controls.miniRouteControls;eq(check:GetChecked(),true)
 check.scripts.OnClick();eq(A.db.settings.routeControls,false);eq(A.RouteControls.frame:IsShown(),false);eq(A.follower,f);eq(A.plan,plan)
 U.frame:Hide();U.Refresh();eq(A.RouteControls.frame:IsShown(),false)
 U.OpenRoutes();eq(check:GetChecked(),false);check.scripts.OnClick();assert(A.RouteControls.frame:IsShown())
 U.actions.stop();U.actions.generateStart();assert(A.RouteControls.frame:IsShown())
 A.db.settings.routeControls=false;U.Refresh();U.actions.stop();U.actions.generateStart();eq(A.RouteControls.frame:IsShown(),false)
end)

test('route controls lifecycle includes paused suspended complete and actual core tick',function()
 local A,U=setup();U.actions.generateStart();local f=A.follower
 for _,status in ipairs({'paused','suspended'}) do f.status=status;U.Refresh();assert(A.RouteControls.frame:IsShown()) end
 module('Core',A);A.initialized=true;A.detector={Expire=function() end,IsGathering=function() return false end}
 A.Arrow={Update=function() end};f.status='running';f.Tick=function(self) self.status='complete' end
 A.Tick(.1);eq(A.RouteControls.frame:IsShown(),false);eq(U.frame:IsShown(),false)
 f.status='running';U.Refresh();assert(A.RouteControls.frame:IsShown());A.follower=nil;U.Refresh();eq(A.RouteControls.frame:IsShown(),false)
end)

test('route control title drag saves normalized position and clamps restored bounds',function()
 local A,U=setup();U.actions.generateStart();local C=A.RouteControls;local f=A.follower
 C.frame.GetCenter=function() return 1440,810 end
 C.titlebar.scripts.OnDragStart(C.titlebar);eq(C.dragging,true);C.titlebar.scripts.OnDragStop(C.titlebar)
 eq(C.dragging,false);near(A.db.settings.routeControlsPosition.x,.75);near(A.db.settings.routeControlsPosition.y,.75);eq(A.follower,f)
 C.Position();near(C.frame.point[4],1440);near(C.frame.point[5],810)
 A.db.settings.routeControlsPosition={x=5,y=-5};C.Position();assert(C.frame.point[4]<=1920-C.frame:GetWidth()/2);assert(C.frame.point[5]>=C.frame:GetHeight()/2)
 A.db.settings.routeControlsPosition={x=0/0,y=math.huge};C.Position();assert(A.Store.Number(C.frame.point[4]));assert(A.Store.Number(C.frame.point[5]))
 C.titlebar.scripts.OnDragStart(C.titlebar);U.actions.stop();eq(C.dragging,false)
end)

test('route control setting fits all fixed panel presets without shrinking review map',function()
 local A,U=setup()
 for _,preset in ipairs({'small','standard','large'}) do
  U.window:SetPreset(preset);U.OpenRoutes();local c=U.controls.miniRouteControls;local marker=U.controls.markerRouteOverride
  assert(c.point[4]>marker.label:GetWidth()+20);assert(c.point[4]+24+c.label:GetWidth()<=U.routeView.frame:GetWidth()+4)
  assert(U.routeSketch.frame:GetHeight()>=300)
 end
end)

test('route controls setting and position survive saved data reopening and nearest-node guidance',function()
 local A,U=setup();A.db.settings.routeControls=false;A.db.settings.routeControlsPosition={x=.25,y=.4}
 A.db=A.Store.Open(A.Store.Copy(A.db));U.Refresh();eq(U.controls.miniRouteControls:GetChecked(),false)
 U.actions.generateStart();eq(A.RouteControls.frame,nil)
 U.actions.stop();A.db.settings.routeControls=true;U.OpenRoutes()
 U.SetTab('codex');U.codexView.SetSearch('Peacebloom');U.codexView.tiles[1].scripts.OnClick(U.codexView.tiles[1]);U.codexView.Guide()
 assert(A.follower);assert(A.RouteControls.frame:IsShown());near(A.RouteControls.frame.point[4],480);near(A.RouteControls.frame.point[5],432)
end)
