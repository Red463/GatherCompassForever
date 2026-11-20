local function setup(count)
 dofile('tests/wow.lua');fakeUI();local A={};for _,name in ipairs({'Store','Client','Editor','Planner','Follower','FarmingSession'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 for i=1,count or 8 do A.Store.Observe(A.db,{mapID=1,x=.1+i*.04,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'}) end
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end

test('terrain review renders every mandatory bend on long routes',function()
 local A,U=setup(0);local route={mapID=1,terrainVersion=1,points={}}
 for i=1,700 do route.points[i]={mapID=1,x=.2+i*.0005,y=i%2==0 and .5 or .501} end
 U.routeSketch:Draw(route,nil,{nodes={},style='lines'})
 local shown=0;for _,line in ipairs(U.routeSketch.lines) do if line:IsShown() then shown=shown+1 end end
 eq(shown,699)
end)

test('review group shares dominant resource icons and compact hover without changing node selection',function()
 local A,U=setup(0)
 for i,id in ipairs({401,402,402}) do A.Store.Observe(A.db,{mapID=1,x=.2+i*.0001,y=.5,kind='herb',materialID='gm:herb:'..id,name=id==401 and 'Peacebloom' or 'Silverleaf',source='imported'}) end
 U.actions.generateReview();local pin=U.routeSketch.pins[1];eq(#pin.group.members,3)
 eq(pin.icon.texture,A.Resources.Icon({kind='herb',materialID='gm:herb:402'}))
 local title,rows;rows={};GameTooltip.SetText=function(_,s) title=s end;GameTooltip.AddDoubleLine=function(_,name,count) rows[#rows+1]={name,count} end
 pin.scripts.OnEnter(pin);eq(title,'3 nodes here');eq(rows[1][1],'Silverleaf');eq(rows[1][2],'x2')
 pin.scripts.OnClick(pin);assert(U.routeSketch.picker.frame:IsShown())
end)
test('Routes exposes quick start first and a larger review instead of manual or saved-library controls',function()
 local A,U=setup();assert(U.routeView);eq(U.routeView.primary,U.controls.generateStart)
 for _,key in ipairs({'new','record','save','deleteRoute','route1','prevRoute','emptyNew'}) do eq(U.controls[key],nil) end
 assert(U.routeSketch.frame:GetWidth()>=700);assert(U.routeSketch.frame:GetHeight()>=270)
end)

test('quick start validates its final join before replacing working guidance',function()
 local A,U=setup();U.actions.generateStart();local f,plan=A.follower,A.plan
 A.Client.Position=function() return nil end
 eq(U.ReviewNodes(plan.candidates,point(.1),true),nil);eq(A.follower,f);eq(A.plan,plan)
end)

test('failed live edits preserve guidance and resume rejoins locally or keeps a pause',function()
 local A,U=setup();U.actions.generateStart();U.OpenRoutes();local f,plan=A.follower,A.plan
 U.actions.selectNode(plan.candidates[1].key);A.Client.Position=function() return point(1) end
 U.actions.removeNode();eq(A.follower,f);eq(plan.route~=nil,true);eq(#plan.undo,0)
 f:Pause();U.actions.pause();eq(f.status,'paused')
 A.Client.Position=function() return point(.4) end;U.actions.pause();eq(f.status,'paused');assert(A.follower~=f);eq(A.follower.status,'running');assert(distance(point(.4),A.follower:Target())<=450)
end)

test('stopped or completed plans retain candidates but clear sketch lines and heat',function()
 local A,U=setup();U.actions.generateStart();U.OpenRoutes();U.actions.routeStyle('heatmap');assert(U.routeSketch.heat[1]:IsShown())
 U.actions.stop();for _,t in ipairs(U.routeSketch.heat) do eq(t:IsShown(),false) end;assert(A.plan.route and #A.plan.candidates>0)
 U.actions.start();U.OpenRoutes();A.follower.status='complete';U.Refresh()
 for _,t in ipairs(U.routeSketch.heat) do eq(t:IsShown(),false) end
 U.actions.routeStyle('lines');for _,l in ipairs(U.routeSketch.lines) do eq(l:IsShown(),false) end
end)

test('review edits cannot replace an unrelated nearest-node follower or revive its old review',function()
 local A,U=setup();U.actions.generateReview();local plan=A.plan
 U.SetTab('codex');U.codexView.SetSearch('Peacebloom');U.codexView.tiles[1].scripts.OnClick(U.codexView.tiles[1]);U.codexView.Guide();local nearest=A.follower;assert(nearest);eq(plan.review,false)
 U.OpenRoutes();U.actions.selectNode(plan.candidates[1].key);U.actions.removeNode();eq(A.follower,nearest);eq(plan.review,false)
 nearest.status='complete';eq(U.DisplayRoute(),nil)
end)

test('dense map drags skip unchanged positions and bound visible pin scanning',function()
 local A,U=setup();U.actions.generateReview();local sketch=U.routeSketch;local nodes={}
 for i=1,20000 do nodes[i]={key='n'..i,mapID=1,x=.3+(i%20)*.001,y=.5+(i%15)*.001,materialID='gm:herb:401',kind='herb'} end
 local plan={candidates=nodes,excluded={},route=A.plan.route,byKey={}};for _,n in ipairs(nodes) do plan.byKey[n.key]=n end
 local calls=0;local key=A.FarmingSession.Key
 A.FarmingSession.Key=function(n) calls=calls+1;return key(n) end
 sketch:Draw(plan.route,nil,{plan=plan,nodes=nodes});assert(calls<=401,'Pin budget scanned '..calls..' nodes')
 calls=0;sketch:Draw(plan.route,nil,{plan=plan,nodes=nodes,selected='n19999'});assert(calls<=401,'Selected pin scanned '..calls..' nodes')
 calls=0;GetCursorPosition=function() return 10,10 end;sketch.viewport.scripts.OnDragStart()
 for i=1,60 do sketch.viewport.scripts.OnUpdate() end;eq(calls,0)
 GetCursorPosition=nil
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

test('a coincident review group chooses and removes just one member with bounded picker rows',function()
 local A,U=setup(0)
 for _,id in ipairs({401,402}) do A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='herb',materialID='gm:herb:'..id,name=id==401 and 'Peacebloom' or 'Silverleaf',source='imported'}) end
 U.actions.generateReview();local sketch=U.routeSketch;local pin=sketch.pins[1];eq(#pin.group.members,2)
 pin.scripts.OnClick(pin);assert(sketch.picker.frame:IsShown());assert(#sketch.picker.rows<=8)
 local row=sketch.picker.rows[2];local key=row.nodeKey;row.scripts.OnClick(row);eq(A.plan.selected,key)
 U.actions.removeNode();eq(A.plan.excluded[key],true);eq(#A.db.nodes[1],2);eq(sketch.picker.frame:IsShown(),false)
 U.actions.undoNode();eq(A.plan.excluded[key],nil)
 U.actions.generateReview();pin=sketch.pins[1];pin.scripts.OnClick(pin);U.Refresh()
 eq(sketch.picker.plan,A.plan);eq(sketch.picker.frame:IsShown(),true)
 U.SetTab('codex');eq(sketch.picker.frame:IsShown(),false)
 U.OpenRoutes();sketch.pins[1].scripts.OnClick(sketch.pins[1]);U.frame:Hide();eq(sketch.picker.frame:IsShown(),false)
end)
