local function setup()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Planner','Follower'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance
 C_Minimap={GetViewRadius=function() return 200 end}
 for i,x in ipairs({.25,.45,.65,.85}) do A.Store.Observe(A.db,{mapID=1,x=x,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'}) end
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end

test('new corridor generation captures minimap range and failed recalibration preserves guidance',function()
 local A,U=setup();U.actions.generateStart();local f,plan=A.follower,A.plan
 assert(plan.route.corridor);near(plan.route.coverageRadius,180);near(plan.route.minimapViewRadius,200)
 Minimap:SetZoom(1);U.actions.generateStart();eq(A.follower,f);eq(A.plan,plan);assert(A.status:find('fully out',1,true))
 Minimap:SetZoom(0);C_Minimap.GetViewRadius=function() error('unavailable') end
 U.actions.generateReview();eq(A.follower,f);eq(A.plan,plan)
end)

test('corridor coverage survives zoom style opacity and removal undo without recalibration',function()
 local A,U=setup();U.actions.generateStart();local plan=A.plan;U.OpenRoutes()
 local radius=plan.route.coverageRadius;local key=plan.candidates[2].key
 Minimap:SetZoom(3);C_Minimap.GetViewRadius=function() return 20 end
 U.Refresh();assert(U.routeView.info:GetText():find('fully out',1,true))
 U.actions.selectNode(key);U.actions.removeNode();near(plan.route.coverageRadius,radius);eq(plan.route.includedKeys[key],nil)
 U.actions.undoNode();near(plan.route.coverageRadius,radius);eq(plan.route.includedKeys[key],true)
 local route,follower=plan.route,A.follower;local count=route.includedCount
 U.actions.routeStyle('heatmap');U.actions.nodeWorldHeatOpacity(nil,20);U.actions.nodeMiniLineOpacity(nil,0)
 eq(A.plan.route,route);eq(A.follower,follower);eq(route.includedCount,count);near(route.coverageRadius,radius)
end)

test('corridor centre guidance uses travel points and leaves gather history unconfirmed',function()
 local A,U=setup();U.actions.generateStart();local f=A.follower
 for _,p in ipairs(f.route.points) do eq(p.kind,'travel');eq(p.name,'Farming corridor') end
 local first=f.index;f:Tick(f:Target(),0,false);assert(f.index~=first or f.lap>0)
 for _,n in ipairs(A.db.nodes[1]) do eq(n.confirmed,nil);eq(n.count,0) end
end)

test('Routes sketch uses world opacity while covered nodes remain selectable',function()
 local A,U=setup();U.actions.generateReview();local sketch=U.routeSketch
 U.actions.nodeWorldLineOpacity(nil,20);assert(sketch.lines[1]:IsShown());near(sketch.lines[1].color[4],.18)
 U.actions.nodeWorldLineOpacity(nil,0);eq(sketch.lines[1]:IsShown(),false);assert(sketch.pins[1]:IsShown())
 local count=A.plan.route.includedCount;U.actions.routeStyle('heatmap');U.actions.nodeWorldHeatOpacity(nil,0)
 for _,t in ipairs(sketch.heat) do eq(t:IsShown(),false) end
 eq(A.plan.route.includedCount,count);assert(sketch.pins[1]:IsShown())
end)

test('a tiny unusable range cannot replace a working plan with a single-stop corridor',function()
 local A,U=setup();U.actions.generateStart();local follower,plan=A.follower,A.plan
 C_Minimap.GetViewRadius=function() return 1e-15 end
 U.ReviewNodes({plan.candidates[1]},point(.1),true)
 eq(A.follower,follower);eq(A.plan,plan)
end)

test('a smaller view at zoom zero warns without rewriting captured coverage',function()
 local A,U=setup();U.actions.generateStart();local plan,follower=A.plan,A.follower;U.OpenRoutes()
 C_Minimap.GetViewRadius=function() return 170 end;U.Refresh()
 assert(U.routeView.info:GetText():find('range is reduced',1,true));eq(A.plan,plan);eq(A.follower,follower);near(plan.route.coverageRadius,180)
 C_Minimap.GetViewRadius=function() return 190 end;U.Refresh()
 assert(not U.routeView.info:GetText():find('range is reduced',1,true))
end)
