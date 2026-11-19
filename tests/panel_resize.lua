local function setup()
 dofile('tests/wow.lua');fakeUI();UIParent:SetSize(1920,1080)
 local A={};module('Store',A);module('Client',A);module('Planner',A);module('Follower',A);moduleUI(A);A.db=A.Store.Open()
 A.Client.Position=function() return point(.3) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.Client.Probe=function() return {loot=true,facing=true,distance=true,minimap=true} end
 assert(A.UI.Build());A.UI.OpenRoutes();return A
end
test('panel geometry validates preferred dimensions and fits only when required',function()
 local A={};module('Store',A);module('PanelWindow',A);local P=A.PanelWindow
 local settings={};local g=P.Resolve(settings,1920,1080,false);eq(g.width,960);eq(g.height,624);eq(g.scale,1)
 settings.panel={width=1400,height=900,x=.8,y=.8};g=P.Resolve(settings,1024,768,false)
 eq(g.width,1000);eq(g.height,744);eq(g.scale,1);eq(settings.panel.width,1400);assert(g.left>=12 and g.top<=756)
 g=P.Resolve(settings,800,500,false);eq(g.width,860);eq(g.height,600);assert(g.scale<1);eq(settings.panel.width,1400)
 settings.panel={width=0/0,height=math.huge,x='bad',y=-20};g=P.Resolve(settings,1920,1080,false);eq(g.width,960);eq(g.height,624);assert(g.left>=12)
 settings.panel={width=1,height=2};g=P.Resolve(settings,1920,1080,false);eq(g.width,860);eq(g.height,600)
end)
test('panel resize persists actual dimensions independently from arrow and compact bar',function()
 local A=setup();local U=A.UI;A.db.settings.arrowScale=1.7;U.window:Resize(1200,820)
 eq(U.frame:GetWidth(),1200);eq(U.frame:GetHeight(),820);eq(U.frame.scale,1);eq(A.db.settings.panel.width,1200)
 U.SetCompact(true);eq(U.frame:GetWidth(),730);eq(U.frame:GetHeight(),98)
 U.SetCompact(false);eq(U.frame:GetWidth(),1200);eq(U.frame:GetHeight(),820)
 U.window:Reset();eq(U.frame:GetWidth(),960);eq(U.frame:GetHeight(),624);eq(A.db.settings.arrowScale,1.7)
end)
test('panel grip uses pointer delta and clears interrupted resize',function()
 local A=setup();local U=A.UI;local x,y=600,500;GetCursorPosition=function() return x,y end
 local b=U.window.grip;b.scripts.OnMouseDown(b,'LeftButton');x=720;y=410
 U.window.driver.scripts.OnUpdate(U.window.driver,.06);eq(U.frame:GetWidth(),1080);eq(U.frame:GetHeight(),714)
 assert(U.window.drag);U.frame:Hide();eq(U.window.drag,nil);assert(not U.window.driver.scripts.OnUpdate)
 GetCursorPosition=nil
end)
test('panel display changes preserve preferred size and reset does not clear filters',function()
 local A=setup();local U=A.UI;U.window:Resize(1400,900);A.db.settings.materials={['gm:herb:402']=true};local original=A.db.settings.materials
 UIParent:SetSize(1024,768);U.frame.scripts.OnEvent(U.frame,'DISPLAY_SIZE_CHANGED');eq(U.frame:GetWidth(),1000);eq(A.db.settings.panel.width,1400)
 UIParent:SetSize(1920,1080);U.frame.scripts.OnEvent(U.frame,'UI_SCALE_CHANGED');eq(U.frame:GetWidth(),1400)
 U.window:Reset();eq(A.db.settings.materials,original)
end)

test('panel reflows routes materials and footer without scaling normal controls',function()
 local A=setup();local U=A.UI
 for _,item in ipairs(A.Resources.Catalog()) do A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind=item.kind,materialID=item.materialID,name=item.name,source='imported'}) end
 U.window:Resize(960,624);local mapW,mapH=U.routeSketch.frame:GetWidth(),U.routeSketch.frame:GetHeight();local listH=U.filterSidebar.scroll:GetHeight()
 U.window:Resize(1400,900);assert(U.routeSketch.frame:GetWidth()>mapW);assert(U.routeSketch.frame:GetHeight()>mapH);assert(U.filterSidebar.scroll:GetHeight()>listH)
 eq(U.controls.generateStart:GetHeight(),26);eq(U.frame.scale,1);eq(U.controls.generateStart.label.fontSize,12)
 U.window:Resize(860,600);assert(U.routeSketch.frame:GetWidth()>500);assert(U.routeSketch.frame:GetHeight()>170);eq(U.routeView.narrow,true)
 eq(U.body:GetHeight(),390);eq(U.footer:GetWidth(),836);eq(U.status:GetWidth(),824)
end)
test('Codex resize changes capacity without losing entries and detail rows use extra height',function()
 local A=setup();local U=A.UI;U.SetTab('codex');local v=U.codexView
 U.window:Resize(860,600);local small=v.capacity;assert(small>0 and small<27);eq(v.filterRows,2)
 local seen={};local total=#v.model.items
 for page=1,math.ceil(total/v.capacity) do v.page=page;U.Refresh();for _,tile in ipairs(v.tiles) do if tile.cell:IsShown() then assert(tile.item and not seen[tile.item.id]);seen[tile.item.id]=true end end end
 local count=0;for _ in pairs(seen) do count=count+1 end;eq(count,total)
 U.window:Resize(1400,900);assert(v.capacity>small);assert(v.capacity>27);eq(v.filterRows,1);eq(v.page,1)
 assert(v.zoneCapacity>7);v.Open(v.model.items[1].id);assert(v.detail:GetWidth()>896)
end)
test('minimum settings and Welcome remain accessible through interior scroll',function()
 local A=setup();local U=A.UI;U.window:Resize(860,600)
 U.SetTab('nodes');eq(U.nodeDisplayView.stacked,true);assert(U.nodeDisplayView.scroller.maximum>0)
 U.nodeDisplayView.scroller:SetOffset(10000);eq(U.nodeDisplayView.scroller.offset,U.nodeDisplayView.scroller.maximum)
 U.SetTab('welcome');assert(U.welcomeView.scroller.maximum>0)
 U.SetTab('settings');eq(U.sidebar:IsShown(),false);assert(U.preferencesScroll.maximum>0);assert(U.controls.resetPanel)
 U.controls.resetPanel.scripts.OnClick();eq(U.frame:GetWidth(),960);eq(U.frame:GetHeight(),624)
end)
test('resize keeps route plan follower and sketch pan while updating projection',function()
 local A=setup();local U=A.UI
 for i=1,8 do A.Store.Observe(A.db,{mapID=1,x=.3+i*.01,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'}) end
 U.actions.generateReview();local plan=A.plan;U.routeSketch:Zoom(1);U.routeSketch:Pan(12,4);local zoom,cx,cy=U.routeSketch.zoom,U.routeSketch.cx,U.routeSketch.cy
 U.window:Resize(1200,820);eq(A.plan,plan);eq(U.routeSketch.zoom,zoom);eq(U.routeSketch.cx,cx);eq(U.routeSketch.cy,cy)
 U.actions.start();local follower=A.follower;U.OpenRoutes();U.window:Resize(1100,750);eq(A.follower,follower);eq(A.plan,plan);eq(follower.status,'running')
end)

test('moving a panel is not overwritten by background refresh and saves the new position',function()
 local A=setup();local U=A.UI;local resets=0
 U.frame.ClearAllPoints=function() resets=resets+1 end
 U.header.scripts.OnDragStart(U.header);U.Refresh();eq(resets,0)
 U.frame.GetCenter=function() return 650,500 end
 U.header.scripts.OnDragStop(U.header);near(A.db.settings.panel.x,650/1920);near(A.db.settings.panel.y,500/1080)
 local left=U.window.geometry.left;local top=U.window.geometry.top
 local x,y=900,600;GetCursorPosition=function() return x,y end
 U.window.grip.scripts.OnMouseDown(U.window.grip,'LeftButton');x=x+40;y=y-40;U.window.driver.scripts.OnUpdate(nil,.05)
 near(U.window.geometry.left,left);near(U.window.geometry.top,top);U.window:Cancel();GetCursorPosition=nil
end)

test('narrow Codex detail keeps ranked column headers inside the scroll body',function()
 local A=setup();local U=A.UI;U.window:Resize(860,600);U.SetTab('codex');local v=U.codexView;v.Open(v.model.items[1].id)
 assert(v.zoneTotals.point[4]+v.zoneTotals:GetWidth()<=v.zones:GetWidth())
 assert(v.zoneHeader:GetWidth()+176+32<=v.zones:GetWidth())
end)
