local function setup()
 dofile('tests/wow.lua');fakeUI();local A={};for _,m in ipairs({'Store','Client','Planner','Follower'}) do module(m,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.3) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance;A.Client.Probe=function() return {loot=true,facing=true,distance=true,minimap=true} end
 A.UI.Build();A.UI.OpenRoutes();return A
end
test('independent marker migration preserves empties and deep copies legacy selections before route edits',function()
 local A={};module('Store',A);module('Selection',A);local s={source='none',kind='herb',materials={a=true,b=false}}
 A.Selection.Init(s);local marker=A.Selection.MarkerSettings(s);eq(marker.source,'none');eq(marker.kind,'herb');eq(marker.materials.a,true)
 s.materials.a=false;s.source='combined';eq(marker.materials.a,true);eq(marker.source,'none');marker.materials.b=true;eq(s.materials.b,false)
 eq(s.routeMarkerOverride,false);local all={};A.Selection.Init(all);eq(A.Selection.MarkerSettings(all).materials,nil)
end)
test('marker override uses copied active selections and stops without changing base markers',function()
 local A={};module('Store',A);module('Selection',A);local s={source='combined',kind='both'};A.Selection.Init(s)
 s.kind='herb';s.materials={silver=true};local f={status='running',markerFilter=A.Selection.Snapshot(A.Selection.Filter(s))}
 eq(A.Selection.EffectiveMarker(s,f).kind,'both');s.routeMarkerOverride=true;eq(A.Selection.EffectiveMarker(s,f).kind,'herb')
 s.materials.silver=false;eq(A.Selection.EffectiveMarker(s,f).materials.silver,true)
 for _,status in ipairs({'paused','suspended'}) do f.status=status;eq(A.Selection.EffectiveMarker(s,f).kind,'herb') end
 f.status='stopped';eq(A.Selection.EffectiveMarker(s,f).kind,'both');eq(A.Selection.MarkerSettings(s).kind,'both')
end)
test('route changes leave map filters alone and generated guidance captures its route choices',function()
 local A=setup();local U=A.UI;local initial=A.Selection.MarkerSettings(A.db.settings)
 U.SetKind('herb');eq(initial.kind,'both')
 for i=1,5 do A.Store.Observe(A.db,{mapID=1,x=.31+i*.01,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'}) end
 U.actions.generateStart();assert(A.follower);eq(A.follower.markerFilter.kind,'herb');U.SetKind('ore');eq(A.follower.markerFilter.kind,'herb')
 U.actions.stop();eq(A.Selection.EffectiveMarker(A.db.settings,A.follower).kind,'both')
end)
test('missing profession is red but unreadable profession data stays unknown',function()
 local A={};module('Store',A);module('Client',A);module('Resources',A);local ore={kind='ore',materialID='gm:ore:201'}
 local d=A.Resources.SkillDetails(ore,{}, {ore={known=false}});eq(d.key,'red');eq(d.summary,'Learn Mining to gather');assert(d.requirement:find('Mining',1,true))
 eq(A.Resources.SkillDetails(ore,{},{}).key,'unknown')
 GetProfessions=function() return 1 end;GetProfessionInfo=function() return 'Herbalism',nil,100,150,0,0,182,0 end
 local ranks,ctx=A.Resources.Skills();eq(ranks.herb,100);eq(ctx.ore.known,false);eq(A.Resources.SkillDetails(ore,ranks,ctx).key,'red')
 GetProfessionInfo=function() error('unreadable') end;ranks,ctx=A.Resources.Skills();assert(not ctx.ore or ctx.ore.known~=false)
 GetProfessions=nil;GetProfessionInfo=nil
end)
