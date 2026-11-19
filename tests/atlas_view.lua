local function viewSetup()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,m in ipairs({'Store','Client','Editor','Recorder','Planner','Follower'}) do module(m,A) end
 moduleUI(A);A.db=A.Store.Open();A.Client.Position=function() return point(.1) end
 A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end;A.Store.distance=distance
 A.Resources.Skills=function() return {herb=109},{herb={maxRank=150,bonus=0}} end
 A.UI.Build();A.UI.OpenRoutes();return A
end
local function put(A,map,x,id,name,source,when)
 return A.Store.Observe(A.db,{mapID=map,x=x,y=.5,kind='herb',materialID=id,name=name,source=source or 'imported',time=when})
end
local function seed(A)
 put(A,1,.2,'gm:herb:402','Silverleaf','confirmed',10);put(A,1,.3,'gm:herb:402','Silverleaf')
 put(A,1,.4,'gm:herb:403','Earthroot','confirmed',20);put(A,1,.4,'gm:herb:403','Earthroot','confirmed',30)
 put(A,1,.5,'gm:herb:409','Wild Steelbloom');put(A,2,.4,'gm:herb:402','Silverleaf')
 A.UI.SetTab('atlas');assert(A.UI.atlasView);return A.UI.atlasView
end
local function pick(view,name)
 for _,row in ipairs(view.rows) do if row.group and row.group.name==name then row.scripts.OnClick(row);return end end
 error('Resource missing: '..name)
end

test('atlas replaces coordinate pages with grouped icon rows and functional dropdown filtering',function()
 local A=viewSetup();local V=seed(A);eq(#V.model.groups,3);eq(#V.rows,4)
 assert(V.rows[1].icon.texture);eq(V.group.name,'Silverleaf');eq(V.group.count,2)
 A.UI.controls.atlasSkill:SelectValue('skillups');eq(#V.model.groups,1);eq(V.group.name,'Earthroot')
 A.UI.controls.atlasSkill:SelectValue('all');A.UI.controls.atlasSort:SelectValue('gathers');eq(V.model.groups[1].name,'Earthroot')
 eq(A.db.settings.source,'combined');eq(A.db.settings.kind,'both');eq(A.db.settings.materials,nil)
end)

test('atlas zone comparisons select a zone and disable impossible cross-zone navigation',function()
 local A=viewSetup();local V=seed(A);A.UI.controls.atlasScope:SelectValue('all');pick(V,'Silverleaf')
 eq(V.group.count,3);A.UI.controls.atlasDetail:SelectValue('zones');eq(#V.group.zones,2)
 local found;for _,row in ipairs(V.detailRows) do if row.entry and row.entry.mapID==2 then found=row end end
 assert(found);found.scripts.OnClick(found);eq(V.scope,2);eq(A.UI.controls.atlasScope:GetValue(),2)
 eq(V.group.name,'Silverleaf');eq(V.group.count,1);eq(A.UI.controls.atlasPlan:IsEnabled(),false);eq(A.UI.controls.atlasGuide:IsEnabled(),false)
 A.UI.controls.atlasScope:SelectValue('current');eq(V.scope,'current');eq(V.group.count,2)
end)

test('atlas plans only the selected resource without changing saved routes or sidebar choices',function()
 local A=viewSetup();local V=seed(A);pick(V,'Silverleaf')
 local saved=A.Store.SaveRoute(A.db,{name='Existing',mapID=1,points={point(.6)}});A.selectedRoute=saved
 V.Plan();assert(A.editor);eq(A.UI.tab,'routes');eq(A.editor.draft.mapID,1);eq(#A.editor.draft.points,2)
 for _,p in ipairs(A.editor.draft.points) do eq(p.name,'Silverleaf') end
 eq(A.db.routes[saved].name,'Existing');eq(A.selectedRoute,saved);eq(A.db.settings.materials,nil)
 local draft=A.editor;V.Plan();eq(A.editor,draft)
end)

test('atlas nearest guidance is a temporary one-point route and respects active work',function()
 local A=viewSetup();local V=seed(A);pick(V,'Silverleaf');V.Guide()
 assert(A.follower);eq(#A.follower.route.points,1);eq(A.follower:Target().name,'Silverleaf');eq(A.UI.frame:IsShown(),false)
 eq(next(A.db.routes),nil);local following=A.follower;V.Plan();eq(A.follower,following);eq(A.editor,nil)
 V.Guide();eq(A.follower,following)
 A.follower=nil;A.editor=A.Editor.New({name='Keep draft',mapID=1,points={point(.5)}});V.Guide();eq(A.editor.draft.name,'Keep draft');eq(A.follower,nil)
end)

test('atlas pages locations and skips expensive queries while hidden or compact',function()
 local A=viewSetup();for i=1,12 do put(A,1,.2+i*.01,'gm:herb:402','Silverleaf') end
 A.UI.SetTab('atlas');local V=A.UI.atlasView;assert(V);eq(#V.detailRows,5)
 eq(V.detailPage,1);A.UI.controls.atlasDetailNext.scripts.OnClick();eq(V.detailPage,2)
 local calls=0;local query=A.Atlas.Query;A.Atlas.Query=function(...) calls=calls+1;return query(...) end
 A.UI.frame:Hide();A.UI.Refresh();eq(calls,0)
 A.UI.frame:Show();A.UI.SetCompact(true);A.UI.Refresh();eq(calls,0)
 A.UI.SetCompact(false);A.UI.SetTab('routes');calls=0;A.UI.Refresh();eq(calls,0)
end)

test('atlas can browse all zones without player coordinates while guidance remains disabled',function()
 local A=viewSetup();local V=seed(A);A.Client.Position=function() return nil end
 A.UI.controls.atlasScope:SelectValue('all');assert(#V.model.groups>0)
 eq(A.UI.controls.atlasGuide:IsEnabled(),false);eq(A.UI.controls.atlasPlan:IsEnabled(),false)
 V.Guide();eq(A.follower,nil);V.Plan();eq(A.editor,nil)
end)


test('atlas map action preserves active navigation and focuses the chosen resource without filter mutation',function()
 local A=viewSetup();local V=seed(A);pick(V,'Silverleaf')
 local following=A.Follower.New({name='Active',mapID=1,points={point(.6),point(.7)}},point(.1),distance);A.follower=following
 local focused,refreshed,mapID
 A.Map={SetNodeFocus=function(id,materials,key,source) focused={id=id,materials=materials,key=key,source=source};return true end,
  Refresh=function(db,route,follower) eq(db,A.db);eq(route,following.route);eq(follower,following);refreshed=true end}
 WorldMapFrame.SetMapID=function(_,value) mapID=value end
 V.ShowMap();eq(focused.id,1);eq(focused.materials['gm:herb:402'],true);eq(focused.source,'combined')
 eq(A.db.settings.materials,nil);eq(A.follower,following);eq(mapID,1);eq(refreshed,true);eq(A.UI.frame:IsShown(),false)
end)

test('atlas materials and counts follow browsing scope without dropping unseen-zone choices',function()
 local A=viewSetup();local V=seed(A);put(A,2,.5,'gm:herb:405','Briarthorn')
 A.UI.controls.atlasScope:SelectValue('all')
 eq(A.UI.controls.kindHerb:GetChecked(),true);eq(A.UI.controls.kindOre:GetChecked(),true)
 eq(A.UI.controls.sourceConfirmed:GetChecked(),true);eq(A.UI.controls.sourceImported:GetChecked(),true)
 local materials={};for _,row in ipairs(A.UI.materialRows) do if row.materialID then materials[row.materialID]=true end end
 assert(materials['gm:herb:405'],'All-zone material absent from sidebar')
 assert(A.UI.sourceCounts:GetText():find('6 matching',1,true))
 A.UI.ToggleMaterial('gm:herb:403')
 eq(A.db.settings.materials['gm:herb:403'],false);eq(A.db.settings.materials['gm:herb:405'],true)
 V.SetScope(2);A.UI.ToggleMaterial('gm:herb:402')
 eq(A.db.settings.materials['gm:herb:405'],true)
 eq(#A.UI.SelectedNodes(),1);eq(A.UI.SelectedNodes()[1].name,'Wild Steelbloom')
 A.db.settings.materials=nil;A.UI.SetTab('routes');A.UI.ToggleMaterial('gm:herb:403')
 eq(A.db.settings.materials['gm:herb:405'],true)
end)
