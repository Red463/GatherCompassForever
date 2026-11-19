local function setup()
 dofile('tests/wow.lua');fakeUI();local A={};for _,n in ipairs({'Store','Client','Planner','Follower'}) do module(n,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.Resources.Skills=function() return {herb=109,ore=260},{herb={maxRank=150,bonus=0},ore={maxRank=300,bonus=0}} end
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end
local function observe(A,id,map,x)
 return A.Store.Observe(A.db,{mapID=map or 1,x=x or .2,y=.5,kind=id<400 and 'ore' or 'herb',materialID='gm:'..(id<400 and 'ore' or 'herb')..':'..id,name=id==215 and 'Rich Thorium Vein' or id==401 and 'Peacebloom' or 'Silverleaf',source='imported'})
end
test('scoped Codex skill-up colours use sources present in the location result',function()
 local A,U=setup();observe(A,215)
 local opts={scope='current',mapID=1,skill='all'};local item=A.ResourceLibrary.Query(A.db,'ore','Thorium',opts).items[1]
 eq(item.skill.key,'red');opts.skill='skillups';eq(#A.ResourceLibrary.Query(A.db,'ore','Thorium',opts).items,0)
 opts={source='imported',skill='gatherable'};eq(#A.ResourceLibrary.Query(A.db,'ore','Thorium',opts).items,0)
 eq(A.ResourceLibrary.Query(A.db,'ore','Thorium').items[1].skill.key,'orange')
end)
test('warm Codex catalogue and scoped queries do not rescan unchanged observations',function()
 local A=setup();A.db.nodes[1]={}
 for i=1,10000 do A.db.nodes[1][i]={key='n'..i,mapID=1,x=(i%100)/100,y=math.floor(i/100)/101,kind='herb',materialID='gm:herb:401',name='Peacebloom',imported=true} end
 A.db.nodeRevision=1
 for _,opts in ipairs({{}, {scope='current',mapID=1,source='imported'}}) do
  A.ResourceLibrary.Query(A.db,'all','',opts);local blocks=0
  debug.sethook(function() blocks=blocks+1 end,'',1000)
  local result=A.ResourceLibrary.Query(A.db,'all','',opts)
  debug.sethook();assert(blocks<150,'Warm query scanned observations: '..blocks..' thousand instructions');assert(#result.items>0)
 end
end)
test('review display and open picker follow shared materials without rewriting the generated plan',function()
 local A,U=setup();local a=observe(A,401);observe(A,402);U.actions.generateReview();local plan=A.plan;local route=plan.route
 local pin=U.routeSketch.pins[1];pin.scripts.OnClick(pin);assert(U.routeSketch.picker.frame:IsShown())
 U.ToggleMaterial(a.materialID);eq(A.plan,plan);eq(plan.route,route);eq(#U.SelectedNodes(),1);eq(U.routeSketch.picker.frame:IsShown(),false)
 for _,p in ipairs(U.routeSketch.pins) do if p:IsShown() then for _,n in ipairs(p.group.members) do assert(n.materialID~=a.materialID) end end end
end)
test('coincident review targets retain a chooser when world-map appearance grouping is disabled',function()
 local A,U=setup();observe(A,401);observe(A,402);A.Resources.Settings(A.db.settings).groupWorld=false;U.actions.generateReview()
 local pin=U.routeSketch.pins[1];eq(#pin.group.members,2);pin.scripts.OnClick(pin);assert(U.routeSketch.picker.frame:IsShown())
end)
test('Codex map actions explain empty shared selections instead of opening an empty map',function()
 local A,U=setup();observe(A,402);U.SetTab('codex');local V=U.codexView;V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1])
 A.Selection.MarkerSettings(A.db.settings).kind='none';U.SetTab('codex');local opened=false
 WorldMapFrame.Show=function() opened=true end;A.Map={SetNodeFocus=function() error('Empty focus must not be installed') end}
 V.ShowZone(1);eq(opened,false);eq(U.frame:IsShown(),true);assert(A.status:find('Visible nodes',1,true));eq(U.controls.codexMap:IsEnabled(),false)
end)

test('Codex map actions require a real intersection between browse and shared provenance',function()
 local A,U=setup();observe(A,402)
 A.Store.Observe(A.db,{mapID=1,x=.4,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='confirmed'})
 A.Selection.MarkerSettings(A.db.settings).source='imported';U.SetTab('codex');local V=U.codexView;U.controls.codexSource:SelectValue('confirmed');V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1])
 A.Map={SetNodeFocus=function() error('Disjoint provenance must not open an empty map') end};V.ShowZone(1)
 assert(A.status:find('Visible nodes',1,true));eq(U.controls.codexMap:IsEnabled(),false)
end)
