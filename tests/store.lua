local function setup() local A={}; module('Store',A); A.Store.distance=distance; return A.Store end
local function node(x,id,source)
 return {mapID=1,x=x,y=.5,kind='herb',materialID=id or 'item:2447',name='Peacebloom',source=source or 'confirmed',time=20}
end

test('indexed importer searches neighbouring cells while preserving first-match history and object separation',function()
 local S=setup();local db=S.Open()
 local a=node(.10499,'node:herb:Peacebloom');a.objectID=100;local personal=S.Observe(db,a)
 local write=S.ImportWriter(db,function() return 1000,500 end)
 local imported=node(.10501,'gm:herb:401','imported');imported.objectID=100
 local merged=write(imported);eq(merged,personal);eq(#db.nodes[1],1);eq(personal.count,1);eq(personal.lastGathered,20);near(personal.x,.10499)
 imported.objectID=101;assert(write(imported)~=personal);eq(#db.nodes[1],2)
 local first=node(.5,'node:herb:Peacebloom');first.key='first';first.confirmed=true;first.count=7
 local second=node(.504,'gm:herb:401','imported');second.key='second';db.nodes[2]={first,second};first.mapID=2;second.mapID=2
 local query=node(.503,'gm:herb:401','imported');query.mapID=2;eq(write(query),first);eq(first.count,7)
end)

test('indexed importer rebuilds after an external gather moves a node across grid cells',function()
 local S=setup();local db=S.Open();local p=S.Observe(db,node(.10499));local write=S.ImportWriter(db,function() return 1000,500 end)
 write(node(.10499,nil,'imported'));S.Observe(db,node(.1098));near(p.x,.1098)
 eq(write(node(.1147,nil,'imported')),p);eq(#db.nodes[1],1);eq(p.count,2)
end)

test('a gather during incremental index construction also invalidates other cached zones',function()
 local S=setup();local db=S.Open();S.Observe(db,node(.2));local other=node(.10499);other.mapID=2;local p=S.Observe(db,other)
 local armed=false;local write=S.ImportWriter(db,function() return 1000,500 end,function()
  if armed then armed=false;local moved=node(.1098);moved.mapID=2;S.Observe(db,moved) end
 end)
 local q=node(.10499,nil,'imported');q.mapID=2;write(q);armed=true;write(node(.2,nil,'imported'))
 q=node(.1147,nil,'imported');q.mapID=2;eq(write(q),p);eq(#db.nodes[2],1)
end)

test('indexed importer preserves ordinary merge behavior without zone metrics and bounds distant comparisons',function()
 local S=setup();local db=S.Open();local write=S.ImportWriter(db,function() end)
 local p=write(node(.2,nil,'imported'));eq(write(node(.204,nil,'imported')),p)
 local calls=0;S.distance=function(a,b) calls=calls+1;return distance(a,b) end
 db=S.Open();write=S.ImportWriter(db,function() return 1000,500 end)
 for i=1,4000 do local o=node((i%100)*.01,nil,'imported');o.y=math.floor(i/100)*.02;write(o) end
 assert(calls<4000*20,'Distant nodes should not be scanned: '..calls)
 eq(write({mapID=1,x=9,y=.5,kind='herb',materialID='bad',source='imported'}),nil)
end)
test('future schema is untouched and uses memory only',function()
 local S=setup(); local old={version=99,nodes={precious=true},custom='keep'}
 local db,w,reason=S.Open(old); eq(w,false); assert(reason); eq(old.nodes.precious,true); eq(old.version,99); assert(db~=old)
end)

test('deleting one saved route preserves other routes node history settings and route IDs',function()
 local A={};module('Store',A);local db=A.Store.Open()
 local node=A.Store.Observe(db,{mapID=1,x=.2,y=.5,kind='herb',materialID='leaf',source='confirmed'})
 local first=A.Store.SaveRoute(db,{mapID=1,name='First',points={point(.2)}})
 local second=A.Store.SaveRoute(db,{mapID=1,name='Second',points={point(.3)}})
 local settings=db.settings;local nextID=db.nextRoute
 assert(A.Store.DeleteRoute(db,first));eq(db.routes[first],nil);eq(db.routes[second].name,'Second')
 eq(db.nodes[1][1],node);eq(db.settings,settings);eq(db.nextRoute,nextID)
 eq(A.Store.Open(db).routes[first],nil);eq(A.Store.DeleteRoute(db,first),nil)
end)
test('confirmed imported retains both sources and excludes other imports',function()
 local S=setup(); local db=S.Open(); local a=S.Observe(db,node(.2,nil,'imported'))
 S.Observe(db,node(.3,nil,'imported')); S.Observe(db,node(.202))
 eq(a.imported,true); eq(a.confirmed,true); eq(a.count,1)
 eq(#S.Select(db,1,{source='confirmed'}),1); eq(#S.Select(db,1,{source='imported'}),2)
 S.Observe(db,node(.2,nil,'imported')); eq(a.count,1); eq(#db.nodes[1],2)
end)
test('nearby distinct material and known object identities remain separate',function()
 local S=setup(); local db=S.Open(); S.Observe(db,node(.2)); S.Observe(db,node(.201,'item:765'))
 local a=node(.202); a.objectID=100; S.Observe(db,a)
 local b=node(.203); b.objectID=101; S.Observe(db,b)
 eq(#db.nodes[1],3)
end)
test('invalid coordinates and observations are rejected',function()
 local S=setup(); local db=S.Open(); local n=node(0/0); eq(S.Observe(db,n),nil)
 n=node(1.5); eq(S.Observe(db,n),nil); n=node(.3); n.kind='mailbox'; eq(S.Observe(db,n),nil)
end)
test('routes copied and persist when database reopened',function()
 local S=setup(); local db=S.Open(); local r={name='Test',mapID=1,loop=true,points={point(.1),point(.2)}}
 local id=assert(S.SaveRoute(db,r)); r.points[1].x=.9; near(db.routes[id].points[1].x,.1)
 local reopened,w=S.Open(db); eq(w,true); eq(reopened.routes[id].name,'Test')
 eq(S.SaveRoute(db,{name='',mapID=1,points={point(.1)}}),nil)
end)
test('installing GatherMate later reconciles same named node without losing confirmation',function()
 local S=setup(); local db=S.Open(); local own=node(.2,'node:herb:Peacebloom'); own.name='Peacebloom'; S.Observe(db,own)
 local imported=node(.2,'gm:herb:401','imported'); imported.name='Peacebloom'; S.Observe(db,imported)
 eq(#db.nodes[1],1); eq(db.nodes[1][1].confirmed,true); eq(db.nodes[1][1].imported,true); eq(db.nodes[1][1].count,1)
end)
