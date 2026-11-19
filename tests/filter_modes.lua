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
 U.OpenRoutes();local option=U.controls.markerRouteOverride
 eq(option:GetParent(),U.routeView.frame);assert(option:IsVisible());option.scripts.OnClick(option)
 eq(A.db.settings.routeMarkerOverride,true);eq(A.Selection.EffectiveMarker(A.db.settings,A.follower).kind,'herb')
 U.SetTab('nodes');eq(option:IsVisible(),false);U.OpenRoutes();eq(option:GetChecked(),true)
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

test('native skill enumeration does not infer absence from collapsed or incomplete headers',function()
 local A={};module('Store',A);module('Client',A);module('Resources',A);GetProfessions=nil;GetProfessionInfo=nil;GetNumSkillLines=nil;GetSkillLineInfo=nil
 local collapsed=false;local mining=false
 C_SkillInfo={GetNumSkillLines=function() return mining and 3 or 2 end,GetSkillLineInfo=function(i)
  if i==1 then return {isHeader=true,isCollapsed=collapsed} end
  return {isHeader=false,isCollapsed=false,skillID=i==2 and 182 or 186,rank=1,maxRank=75,modifier=0,tempPoints=0}
 end}
 local ranks,ctx=A.Resources.Skills();eq(ctx.ore.known,false);collapsed=true;ranks,ctx=A.Resources.Skills();assert(not ctx.ore or ctx.ore.known~=false)
 collapsed=false;mining=true;ranks,ctx=A.Resources.Skills();eq(ctx.ore.known,true);eq(ranks.ore,1)
 mining=false;ranks,ctx=A.Resources.Skills();eq(ctx.ore.known,false);C_SkillInfo=nil
end)

test('a listed profession with unreadable rank stays known but its difficulty stays neutral',function()
 local A={};module('Store',A);module('Client',A);module('Resources',A);C_SkillInfo=nil;GetNumSkillLines=nil;GetSkillLineInfo=nil
 GetProfessions=function() return 1 end;GetProfessionInfo=function() return 'Mining',nil,nil,75,0,0,186,nil end
 local ranks,ctx=A.Resources.Skills();eq(ctx.ore.known,true);eq(A.Resources.SkillDetails({kind='ore',materialID='gm:ore:201'},ranks,ctx).key,'unknown')
 GetProfessions=nil;GetProfessionInfo=nil
 C_SkillInfo={GetNumSkillLines=function() return 1 end,GetSkillLineInfo=function() return {isHeader=false,isCollapsed=false,skillID=nil,rank=1} end}
 ranks,ctx=A.Resources.Skills();assert(not ctx.ore or ctx.ore.known~=false);C_SkillInfo=nil
end)
