test('display settings preserve old appearance while adding independent map grouping and size',function()
 local A={};module('Store',A);module('Resources',A)
 local settings={nodeDisplay={iconSize=18,outlineSize=28,worldIconOpacity=.25,miniIconOpacity=.5,miniOutlineOpacity=.75,routeLines=false}}
 local s=A.Resources.Settings(settings);eq(s.worldIconSize,18);eq(s.iconSize,18);eq(s.groupWorld,true);eq(s.groupMini,true);eq(s.routeOpacity,.35);eq(s.routeLines,false)
 s.iconSize=12;eq(A.Resources.Settings(settings).worldIconSize,18);s.groupWorld=false;s.routeOpacity=0
 eq(A.Resources.Settings(settings).groupWorld,false);eq(s.routeOpacity,0)
 local n={kind='herb',materialID='gm:herb:401'};eq(A.Resources.Presentation(n,settings,false).iconSize,18);eq(A.Resources.Presentation(n,settings,true).iconSize,12)
end)
test('Node display provides full-width world and minimap pages without diagnostic clutter',function()
 dofile('tests/wow.lua');fakeUI();local A={};module('Store',A);module('Client',A);moduleUI(A);A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance
 A.UI.Build();A.UI.frame:Show();A.UI.SetTab('nodes');local U=A.UI;local V=U.nodeDisplayView;assert(V)
 eq(U.sidebar:IsShown(),false);eq(U.content:GetWidth(),936);eq(V.world:IsShown(),true);eq(V.mini:IsShown(),false);eq(U.controls.inspectNode,nil);eq(U.professionRanks,nil)
 U.controls.displayMini.scripts.OnClick();eq(V.mini:IsShown(),true);eq(V.world:IsShown(),false)
 U.controls.nodeGroupMini.scripts.OnClick();eq(A.Resources.Settings(A.db.settings).groupMini,false)
 U.controls.nodeWorldIconSize:SelectValue(20);eq(A.Resources.Settings(A.db.settings).worldIconSize,20)
 U.controls.nodeRouteOpacity.scripts.OnValueChanged(U.controls.nodeRouteOpacity,0);eq(A.Resources.Settings(A.db.settings).routeOpacity,0)
 U.controls.nodeMini.scripts.OnClick();eq(U.controls.nodeIconSize:IsEnabled(),false);eq(U.controls.nodeRouteLine:IsEnabled(),true)
end)
