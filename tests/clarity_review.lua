local function setup()
 dofile('tests/wow.lua');fakeUI();C_AddOns=nil;GetAddOnMetadata=nil;local A={};for _,m in ipairs({'Store','Client','Planner','Follower'}) do module(m,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.3) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance;A.Client.Probe=function() return {loot=true,facing=true,distance=true,minimap=true} end
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end
local function node(A,id,x,source,map)
 return A.Store.Observe(A.db,{mapID=map or 1,x=x,y=.5,kind=id<400 and 'ore' or 'herb',materialID='gm:'..(id<400 and 'ore' or 'herb')..':'..id,name=id==214 and 'Small Thorium Vein' or id==215 and 'Rich Thorium Vein' or id==201 and 'Copper Vein' or 'Silverleaf',source=source or 'imported'})
end

test('route removal and undo preserve confirmed pickup memory while new generation resets it',function()
 local A,U=setup();for _,x in ipairs({.3,.5,.7}) do node(A,402,x) end
 U.actions.generateStart();local f=A.follower;local p=f.route.points[2]
 local o={mapID=1,x=p.x,y=p.y,kind='herb',materialID='gm:herb:402',source='confirmed'}
 assert(f:ConfirmGather(o));local gatheredKey=p.nodeKey
 A.plan.selected=gatheredKey;U.actions.removeNode();assert(A.follower~=f);eq(#A.follower.gatherRecords,1)
 U.actions.undoNode();local restored
 for i,n in ipairs(A.follower.route.points) do if n.nodeKey==gatheredKey and n.kind=='gather' then restored=i end end
 assert(restored and A.follower.collected[restored]);U.actions.generateStart();eq(next(A.follower.collected),nil)
end)
test('resource-only review start and rebuild carry a narrow override without false sidebar changes',function()
 local A,U=setup();local silver=node(A,402,.35);node(A,402,.40);node(A,402,.45);local copper=node(A,201,.36)
 A.db.settings.routeMarkerOverride=true;U.SetTab('codex');local v=U.codexView;v.SetSearch('Silverleaf');v.Open(v.tiles[1].item.id);v.Plan()
 assert(A.plan:Matches(U.Filter()));U.actions.start();local filter=A.Selection.EffectiveMarker(A.db.settings,A.follower)
 assert(A.Selection.Matches(silver,filter));assert(not A.Selection.Matches(copper,filter))
 A.plan.selected=silver.key;U.actions.removeNode();filter=A.Selection.EffectiveMarker(A.db.settings,A.follower);assert(not A.Selection.Matches(copper,filter))
end)
test('resource snapshots include all route-eligible vein variants independently of Codex source',function()
 local A,U=setup();node(A,214,.32,'confirmed');local rich=node(A,215,.34,'imported');U.SetSource('imported');A.db.settings.routeMarkerOverride=true
 U.SetTab('codex');U.controls.codexSource:SelectValue('confirmed');local v=U.codexView;v.SetSearch('Thorium');v.Open(v.tiles[1].item.id)
 v.Guide();assert(A.Selection.Matches(rich,A.Selection.EffectiveMarker(A.db.settings,A.follower)))
 U.actions.stop();U.frame:Show();U.SetTab('codex');v.Plan();assert(A.plan:Matches(U.Filter()));U.actions.start();assert(A.Selection.Matches(rich,A.Selection.EffectiveMarker(A.db.settings,A.follower)))
end)
test('alias promotion preserves independent preferences snapshots and observations in other zones',function()
 for _,markerOn in ipairs({true,false}) do
  local A={};module('Store',A);module('Selection',A);local db=A.Store.Open();local old='node:herb:Silverleaf';db.settings.materials={[old]=true};A.Selection.Init(db.settings);db.settings.markerFilters.materials[old]=markerOn
  local input={mapID=1,x=.2,y=.5,kind='herb',materialID=old,name='Silverleaf',source='confirmed'};A.Store.Observe(db,input);input.mapID=2;A.Store.Observe(db,input)
  local f={status='running',markerFilter=A.Selection.Snapshot(A.Selection.Filter(db.settings))}
  A.Store.Observe(db,{mapID=1,x=.2,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
  for _,map in ipairs({1,2}) do
   eq(#A.Store.Select(db,map,A.Selection.Filter(db.settings)),1)
   eq(#A.Store.Select(db,map,A.Selection.EffectiveMarker(db.settings,nil)),markerOn and 1 or 0)
   db.settings.routeMarkerOverride=true;eq(#A.Store.Select(db,map,A.Selection.EffectiveMarker(db.settings,f)),1)
  end
  eq(f.markerFilter.materials[old],true);eq(db.settings.markerFilters.materials[old],markerOn)
 end
end)
test('transparent Codex focus is disabled consistently with an opacity-specific remedy',function()
 local A,U=setup();node(A,402,.35);local opened=false;WorldMapFrame.Show=function() opened=true end
 A.Map={SetNodeFocus=function() error('Transparent focus must not open') end};A.Resources.Settings(A.db.settings).worldIconOpacity=0
 U.SetTab('codex');local v=U.codexView;v.SetSearch('Silverleaf');v.Open(v.tiles[1].item.id)
 eq(U.controls.codexMap:IsEnabled(),false);eq(v.zoneRows[1]:IsEnabled(),false);v.ShowZone(1);eq(opened,false);assert(A.status:lower():find('opacity',1,true))
end)
test('blocked map action explains the active route override rather than changing everyday selections',function()
 local A,U=setup();node(A,402,.35);A.follower=A.Follower.New({mapID=1,points={point(.35)}},point(.3),distance)
 A.follower.markerFilter={source='combined',kind='ore'};A.db.settings.routeMarkerOverride=true;A.Map={SetNodeFocus=function() error('Excluded resource must not open') end}
 U.SetTab('codex');local v=U.codexView;v.SetSearch('Silverleaf');v.Open(v.tiles[1].item.id);v.ShowZone(1)
 assert(A.status:lower():find('override',1,true));assert(A.status:find('Stop',1,true) or A.status:find('stop',1,true))
end)
test('title and runtime version prefer installed metadata over the source fallback',function()
 local A,U=setup();A.version='0.13.0';C_AddOns={GetAddOnMetadata=function() return '0.13.0-test.2' end}
 eq(A.Skin.Window(UIParent).title,'Gather Compass Forever v0.13.0-test.2');module('Core',A);eq(A.version,'0.13.0-test.2');C_AddOns=nil
end)

test('Codex disabled-map tooltip gives the same actionable opacity reason as the action',function()
 local A,U=setup();node(A,402,.35);A.Map={SetNodeFocus=function() end};A.Resources.Settings(A.db.settings).worldIconOpacity=0
 U.SetTab('codex');local v=U.codexView;v.SetSearch('Silverleaf');v.Open(v.tiles[1].item.id)
 local lines={};GameTooltip.AddLine=function(_,text) lines[#lines+1]=text end
 U.controls.codexMap.scripts.OnEnter(U.controls.codexMap);assert(table.concat(lines):lower():find('opacity',1,true))
end)
test('canonical aliases preserve exact exclusions and survive saved-data reload',function()
 local A={};module('Store',A);module('Selection',A);local db=A.Store.Open();local old='node:herb:Silverleaf';local new='gm:herb:402'
 db.settings.materials={[old]=true};A.Selection.Init(db.settings);db.settings.markerFilters.materials={[old]=false,[new]=true}
 A.Store.Observe(db,{mapID=1,x=.2,y=.5,kind='herb',materialID=old,name='Silverleaf',source='confirmed'})
 A.Store.Observe(db,{mapID=2,x=.2,y=.5,kind='herb',materialID=old,name='Silverleaf',source='confirmed'})
 A.Store.Observe(db,{mapID=1,x=.2,y=.5,kind='herb',materialID=new,name='Silverleaf',source='imported'})
 db=A.Store.Open(A.Store.Copy(db));local filter=A.Selection.EffectiveMarker(db.settings,nil)
 eq(db.settings.markerFilters.materials[old],false);eq(db.settings.markerFilters.materials[new],true)
 eq(#A.Store.Select(db,1,filter),1);eq(#A.Store.Select(db,2,filter),0)
end)
