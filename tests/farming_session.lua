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

test('failed removal and undo preserve the working route exclusions and undo transaction',function()
 local A,nodes=setup();local session=A.FarmingSession.New(nodes,point(.3),function(a,b) local d=distance(a,b);return d and d*2 end)
 local route,revision=session.route,session.revision
 eq(session:Remove('n1',point(1)),nil);eq(session.route,route);eq(session.revision,revision);eq(session.excluded.n1,nil);eq(#session.undo,0)
 assert(session:Remove('n1',point(.3)));route=session.route;revision=session.revision
 eq(session:Undo(point(1)),nil);eq(session.route,route);eq(session.revision,revision);eq(session.excluded.n1,true);eq(#session.undo,1)
 assert(session:Undo(point(.3)));eq(session.excluded.n1,nil)
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

test('optimized session removal and undo keep gather identities short closure and local guidance',function()
 local A,nodes=setup();module('Follower',A)
 local session=A.FarmingSession.New(nodes,point(.1),distance)
 local function verify(removed)
  local gathered={};local route=session.route
  for i,p in ipairs(route.points) do
   assert(distance(p,route.points[i%#route.points+1])<=450.00001)
   if p.kind=='gather' then assert(not gathered[p.nodeKey]);gathered[p.nodeKey]=true;eq(p.resourceKind,'herb');eq(p.materialID,'herb') end
  end
  for i=1,5 do eq(not not gathered['n'..i],i~=removed) end
  local start=point(.22);local f=A.Follower.New(route,start,distance);eq(f.status,'running');eq(f:Target().nodeKey,'n1')
  f:Tick(start,0,false);assert(distance(start,f:Target())<=450.00001)
 end
 verify();assert(session:Remove('n3',point(.1)));verify(3)
 assert(session:Undo(point(.1)));verify();eq(#nodes,5)
end)
