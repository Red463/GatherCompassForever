local function setup(count)
 dofile('tests/wow.lua');fakeUI();local A={};for _,name in ipairs({'Store','Client','Editor','Planner','Follower','FarmingSession'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 for i=1,count or 8 do A.Store.Observe(A.db,{mapID=1,x=.1+i*.04,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'}) end
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end
test('Routes exposes quick start first and a larger review instead of manual or saved-library controls',function()
 local A,U=setup();assert(U.routeView);eq(U.routeView.primary,U.controls.generateStart)
 for _,key in ipairs({'new','record','save','deleteRoute','route1','prevRoute','emptyNew'}) do eq(U.controls[key],nil) end
 assert(U.routeSketch.frame:GetWidth()>=700);assert(U.routeSketch.frame:GetHeight()>=270)
end)
test('quick start and review share generation while preserving archived routes and node history',function()
 local A,U=setup();local archived=A.Store.SaveRoute(A.db,{name='Archive',mapID=1,points={point(.7)}})
 local count=#A.db.nodes[1];U.controls.generateStart.scripts.OnClick();assert(A.follower and A.plan);eq(A.plan.review,false);eq(U.frame:IsShown(),false)
 U.OpenRoutes();U.controls.generateReview.scripts.OnClick();eq(A.follower,nil);eq(A.plan.review,true);eq(U.frame:IsShown(),true)
 assert(A.db.routes[archived]);eq(#A.db.nodes[1],count);U.controls.start.scripts.OnClick();assert(A.follower);eq(U.frame:IsShown(),false)
end)
test('removal and undo update a paused route without deleting a stored spawn or resetting its lap',function()
 local A,U=setup();U.controls.generateStart.scripts.OnClick();A.follower:Pause();A.follower.lap=3;U.OpenRoutes()
 local key=A.plan.candidates[1].key;local count=#A.db.nodes[1]
 U.actions.selectNode(key);U.controls.removeNode.scripts.OnClick();eq(A.plan.excluded[key],true);eq(#A.db.nodes[1],count)
 eq(A.follower.status,'paused');eq(A.follower.lap,3)
 for _,p in ipairs(A.plan.route.points) do assert(p.nodeKey~=key) end
 U.controls.undoNode.scripts.OnClick();eq(A.plan.excluded[key],nil);eq(A.follower.status,'paused')
end)
test('last removal stops guidance and remains undoable; failed regeneration preserves a working plan',function()
 local A,U=setup(1);U.controls.generateStart.scripts.OnClick();local old=A.follower;local session=A.plan
 A.Client.Position=function() return nil end;U.actions.generateStart();eq(A.follower,old);eq(A.plan,session)
 A.Client.Position=function() return point(.1) end;U.OpenRoutes();U.actions.selectNode(session.candidates[1].key);U.actions.removeNode();eq(A.follower,nil);eq(A.plan.route,nil)
 U.actions.undoNode();assert(A.plan.route);eq(A.follower,nil)
end)
test('filter and display changes preserve the current plan until explicit regeneration',function()
 local A,U=setup();U.controls.generateStart.scripts.OnClick();local f=A.follower;local route=A.plan.route;U.OpenRoutes()
 U.SetKind('ore');eq(A.follower,f);eq(A.plan.route,route);assert(U.routeView.info:GetText():find('Selections changed',1,true))
 U.controls.routeStyle:SelectValue('heatmap');eq(A.db.settings.routeStyle,'heatmap');eq(A.follower,f);eq(A.plan.route,route)
end)

test('review nodes can be selected and removed on a clipped map without resetting zoom',function()
 local A,U=setup();U.actions.generateReview();local sketch=U.routeSketch
 assert(sketch.art);assert(sketch.viewport);assert(sketch.pins[1]);local pin=sketch.pins[1]
 pin.scripts.OnClick(pin);eq(A.plan.selected,pin.nodeKey)
 sketch:Zoom(2);local zoom=sketch.zoom;assert(zoom>1 and zoom<=8)
 U.actions.removeNode();eq(sketch.zoom,zoom)
 for _,p in ipairs(sketch.pins) do if p:IsShown() then assert(not A.plan.excluded[p.nodeKey]) end end
 sketch:Pan(100000,100000);assert(sketch.cx>=0 and sketch.cx<=1 and sketch.cy>=0 and sketch.cy<=1)
 sketch.frame:Hide();eq(sketch.dragging,nil)
end)
