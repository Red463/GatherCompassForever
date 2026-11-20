test('display settings preserve old appearance while adding independent map grouping and size',function()
 local A={};module('Store',A);module('Resources',A)
 local settings={nodeDisplay={iconSize=18,outlineSize=28,worldIconOpacity=.25,miniIconOpacity=.5,miniOutlineOpacity=.75,routeLines=false}}
 local s=A.Resources.Settings(settings);eq(s.worldIconSize,18);eq(s.iconSize,18);eq(s.groupWorld,true);eq(s.groupMini,true);eq(s.routeOpacity,.65);eq(s.routeLines,false)
 s.iconSize=12;eq(A.Resources.Settings(settings).worldIconSize,18);s.groupWorld=false;s.routeOpacity=0
 eq(A.Resources.Settings(settings).groupWorld,false);eq(s.routeOpacity,0)
 local n={kind='herb',materialID='gm:herb:401'};eq(A.Resources.Presentation(n,settings,false).iconSize,18);eq(A.Resources.Presentation(n,settings,true).iconSize,12)
end)
local function nodeDisplay()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Planner','Follower'}) do module(name,A) end
 moduleUI(A);A.db=A.Store.Open();A.Client.Position=function() return point(.3) end;A.Client.Distance=distance
 A.Client.Size=function() return 1000,500 end
 assert(A.UI.Build());A.UI.frame:Show();A.UI.SetTab('nodes');A.UI.nodeDisplayView.SetPage('world')
 return A,A.UI,A.UI.nodeDisplayView
end
test('Node display provides full-width world and minimap pages without diagnostic clutter',function()
 local A,U,V=nodeDisplay()
 eq(U.sidebar:IsShown(),false);eq(U.content:GetWidth(),U.frame:GetWidth()-24);eq(V.world:IsShown(),true);eq(V.mini:IsShown(),false);eq(U.controls.inspectNode,nil);eq(U.professionRanks,nil)
 U.controls.displayMini.scripts.OnClick();eq(V.mini:IsShown(),true);eq(V.world:IsShown(),false)
 U.controls.nodeGroupMini.scripts.OnClick();eq(A.Resources.Settings(A.db.settings).groupMini,false)
 U.controls.nodeWorldIconSize:SetValue(20);eq(A.Resources.Settings(A.db.settings).worldIconSize,20)
 U.controls.nodeMini.scripts.OnClick();eq(U.controls.nodeIconSize:IsEnabled(),false);eq(U.controls.nodeRouteLine:IsEnabled(),true)
end)

test('marker size sliders support small whole-number sizes with plain labels and live previews',function()
 local A,U,V=nodeDisplay()
 for _,choice in ipairs({{'world','nodeWorldIconSize','worldIconSize','Icon size',7},{'mini','nodeOutlineSize','outlineSize','Outline size',9},{'mini','nodeIconSize','iconSize','Icon size',5}}) do
  V.SetPage(choice[1]);local control=U.controls[choice[2]]
  eq(control.kind,'Slider');local lo,hi=control:GetMinMaxValues();eq(lo,4);eq(hi,32)
  eq(control.lowLabel:GetText(),'4');eq(control.highLabel:GetText(),'32')
  control:SetValue(choice[5]);eq(A.Resources.Settings(A.db.settings)[choice[3]],choice[5])
  eq(V.sizeLabels[choice[2]]:GetText(),choice[4]..': '..choice[5])
 end
 eq(V.miniOutline:GetWidth(),9);eq(V.miniIcon:GetWidth(),5)
 local saved=A.Resources.Settings(A.Store.Open(A.Store.Copy(A.db)).settings)
 eq(saved.worldIconSize,7);eq(saved.outlineSize,9);eq(saved.iconSize,5)
end)
test('four route opacity controls persist independent values without changing active navigation',function()
 local A,U,V=nodeDisplay()
 local candidates={}
 for i=1,3 do
  candidates[i]=A.Store.Observe(A.db,{mapID=1,x=.3+(i-1)*.08,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 end
 local plan=assert(A.FarmingSession.New(candidates,A.Client.Position(),distance))
 A.plan=plan;U.actions.start()
 local follower=assert(A.follower);follower:Skip();follower:Pause()
 U.frame:Show();U.SetTab('nodes')
 local route,revision,snapshot=plan.route,plan.revision,follower:Snapshot()
 for _,choice in ipairs({
  {'world','nodeWorldLineOpacity',0,'Line opacity: 0%'},
  {'world','nodeWorldHeatOpacity',45,'Heatmap opacity: 45%'},
  {'mini','nodeMiniLineOpacity',30,'Line opacity: 30%'},
  {'mini','nodeMiniHeatOpacity',85,'Heatmap opacity: 85%'},
 }) do
  V.SetPage(choice[1]);local slider=assert(U.controls[choice[2]],'Missing '..choice[2])
  assert(slider:IsVisible());slider:SetValue(choice[3]);eq(V.opacityLabels[choice[2]]:GetText(),choice[4])
  eq(A.follower,follower);eq(follower:Target(),snapshot.target);eq(follower.index,snapshot.index)
  eq(follower.status,snapshot.status);eq(follower.lap,snapshot.lap);eq(follower.direction,snapshot.direction)
  eq(A.plan,plan);eq(plan.route,route);eq(plan.revision,revision);eq(plan.review,false)
 end
 eq(U.controls.nodeRouteOpacity,nil)
 local saved=A.Resources.Settings(A.Store.Open(A.Store.Copy(A.db)).settings)
 eq(saved.worldLineOpacity,0);near(saved.worldHeatOpacity,.45);near(saved.miniLineOpacity,.30);near(saved.miniHeatOpacity,.85)
 eq(saved.worldIconOpacity,1);eq(saved.miniIconOpacity,1);eq(saved.miniOutlineOpacity,1)
end)
test('only the minimap route master controls availability of minimap route opacity sliders',function()
 local A,U,V=nodeDisplay();local c=U.controls
 assert(c.nodeWorldLineOpacity and c.nodeWorldHeatOpacity and c.nodeMiniLineOpacity and c.nodeMiniHeatOpacity,'Missing separate opacity controls')
 c.nodeWorld.scripts.OnClick();eq(c.nodeWorldOpacity:IsEnabled(),false)
 eq(c.nodeWorldLineOpacity:IsEnabled(),true);eq(c.nodeWorldHeatOpacity:IsEnabled(),true)
 V.SetPage('mini');c.nodeMini.scripts.OnClick()
 eq(c.nodeMiniIconOpacity:IsEnabled(),false);eq(c.nodeOutlineOpacity:IsEnabled(),false)
 eq(c.nodeMiniLineOpacity:IsEnabled(),true);eq(c.nodeMiniHeatOpacity:IsEnabled(),true)
 c.nodeMiniLineOpacity:SetValue(15);c.nodeMiniHeatOpacity:SetValue(0)
 c.nodeRouteLine.scripts.OnClick()
 eq(c.nodeMiniLineOpacity:IsEnabled(),false);eq(c.nodeMiniHeatOpacity:IsEnabled(),false)
 eq(c.nodeWorldLineOpacity:IsEnabled(),true);eq(c.nodeWorldHeatOpacity:IsEnabled(),true)
 local s=A.Resources.Settings(A.db.settings);near(s.miniLineOpacity,.15);eq(s.miniHeatOpacity,0)
 c.nodeRouteLine.scripts.OnClick();eq(c.nodeMiniLineOpacity:IsEnabled(),true);eq(c.nodeMiniHeatOpacity:IsEnabled(),true)
end)
test('display sliders and their endpoint labels fit within each fixed panel size',function()
 local _,U,V=nodeDisplay()
 for _,preset in ipairs({'small','standard','large'}) do
  U.window:SetPreset(preset)
  for page,keys in pairs({world={'nodeWorldIconSize','nodeWorldLineOpacity','nodeWorldHeatOpacity'},mini={'nodeOutlineSize','nodeIconSize','nodeMiniLineOpacity','nodeMiniHeatOpacity'}}) do
   V.SetPage(page)
   for _,key in ipairs(keys) do
    local slider=assert(U.controls[key],'Missing '..key);local caption=V.opacityLabels[key] or V.sizeLabels[key]
    local card=slider:GetParent();local cardX,cardY=card.point[4],-card.point[5]-V[page].point[5]
    eq(caption.fontSize,12);eq(slider.lowLabel.fontSize,11);eq(slider.highLabel.fontSize,11)
    eq(U.frame.scale,1);assert(slider:IsVisible())
    assert(cardX+card:GetWidth()<=V.scroller.body:GetWidth())
    assert(cardY+card:GetHeight()<=V.scroller.scroll:GetHeight()+V.scroller.maximum)
    assert(slider.point[4]+slider:GetWidth()<=card:GetWidth())
    assert(-slider.point[5]+slider:GetHeight()+3+slider.lowLabel:GetHeight()<=card:GetHeight())
   end
  end
 end
end)
