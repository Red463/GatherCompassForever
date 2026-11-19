local function setup()
 local A={};for _,name in ipairs({'Store','Planner','FarmingSession'}) do module(name,A) end
 local nodes={};for i=1,5 do nodes[i]={key='n'..i,mapID=1,x=.1+i*.12,y=.5,kind='herb',materialID='herb',name='Herb'} end
 return A,nodes
end
test('farming session snapshots candidates and removes or restores a spawn without changing history',function()
 local A,nodes=setup();local original=nodes[1].x
 local session=A.FarmingSession.New(nodes,point(.1),distance,{filter={source='combined',kind='herb'}});assert(session and session.route)
 assert(session:Remove('n1',point(.1)));eq(session.excluded.n1,true);eq(nodes[1].x,original);eq(#nodes,5)
 for _,p in ipairs(session.route.points) do assert(p.nodeKey~='n1') end
 assert(session:Undo(point(.1)));eq(session.excluded.n1,nil)
 nodes[1].x=.9;eq(session.candidates[1].x,original)
end)
test('removing the last candidate leaves an undoable empty plan and invalid removals are ignored',function()
 local A,nodes=setup();local session=A.FarmingSession.New({nodes[1]},point(.1),distance)
 eq(session:Remove('missing',point(.1)),nil);eq(#session.undo,0)
 session:Remove('n1',point(.1));eq(session.route,nil);eq(#session.undo,1)
 session:Undo(point(.1));assert(session.route);eq(#session.undo,0)
end)
test('session notices changed selections without rewriting the current generated route',function()
 local A,nodes=setup();local session=A.FarmingSession.New(nodes,point(.1),distance,{filter={source='combined',kind='herb'}})
 local route=session.route;eq(session:Matches({source='combined',kind='herb'}),true)
 eq(session:Matches({source='confirmed',kind='herb'}),false);eq(session.route,route)
end)
