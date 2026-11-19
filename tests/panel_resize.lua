local function setup()
 dofile('tests/wow.lua');fakeUI();UIParent:SetSize(1920,1080)
 local A={};module('Store',A);module('Client',A);moduleUI(A);A.db=A.Store.Open()
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
