local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function fixture(lines,width,height)
 local rows={};local w=#lines[1]
 for y,line in ipairs(lines) do
  local encoded={}
  for first=1,w,6 do
   local n=0
   for x=first,first+5 do n=n*2+(line:sub(x,x)=='1' and 1 or 0) end
   encoded[#encoded+1]=alphabet:sub(n+1,n+1)
  end
  rows[y]=table.concat(encoded)
 end
 local A={TerrainData={version=1,zones={[1]={w=w,h=#lines,widthYards=width or w*10,heightYards=height or #lines*10,rows=rows,status='complete'}}}}
 module('Terrain',A)
 local function p(x,y) return {mapID=1,x=(x-.5)/w,y=(y-.5)/#lines} end
 return A.Terrain,p,A
end

test('terrain decodes six-bit rows including padding and swimming cells',function()
 local T,p=fixture({'1010011','1111111'})
 assert(T.Allowed(p(1,1)));assert(not T.Allowed(p(2,1)));assert(T.Allowed(p(7,1)))
 -- The packaged bit represents permitted ground OR liquid; neither is penalized.
 assert(T.Segment(p(1,2),p(7,2)));near(T.Distance(p(1,2),p(7,2)),60)
end)

test('distance-limited terrain searches do not poison longer or unrestricted searches',function()
 local T,p=fixture({'11011','11011','11011','11111','11011'},100,100)
 local a,b=p(2,1),p(4,1)
 local short,reason=T.Path(a,b,{maxDistance=45});eq(short,nil);eq(reason,'too long')
 local full,length=T.Path(a,b);assert(full);assert(length>45)
 local accepted,d=T.Path(a,b,{maxDistance=200});assert(accepted);near(d,length)
 local reversed,why=T.Path(b,a,{maxDistance=45});eq(reversed,nil);eq(why,'too long')
end)

test('distance-limited searches enforce direct distance and preserve explicit work budgets',function()
 local T,p=fixture({'11111'});local a,b=p(1,1),p(5,1)
 local path,reason=T.Path(a,b,{maxDistance=39});eq(path,nil);eq(reason,'too long')
 assert(T.Path(a,b,{maxDistance=40}))
 for _,n in ipairs({-1,0/0,math.huge}) do local r,why=T.Path(a,b,{maxDistance=n});eq(r,nil);eq(why,'invalid distance') end
 T,p=fixture({'11011','11011','11011','11111','11011'},100,100)
 local r,why=T.Path(p(2,1),p(4,1),{maxDistance=200,budget=0});eq(r,nil);eq(why,'budget')
 assert(T.Path(p(2,1),p(4,1),{maxDistance=200}))
end)

test('terrain missing or malformed data never permits straight-line fallback',function()
 local T,p,A=fixture({'111','111'})
 A.TerrainData.zones[1].status='unavailable';eq(T.Zone(1),nil);assert(not T.Allowed(p(1,1)))
 local path,reason=T.Path(p(1,1),p(3,1));eq(path,nil);eq(reason,'unavailable')
 A.TerrainData.zones[1].status='partial';A.TerrainData.zones[1].rows[1]=''
 assert(not T.Allowed(p(1,1)));assert(T.Allowed(p(1,2)))
 for _,bad in ipairs({{}, {mapID=1,x=0/0,y=.5}, {mapID=1,x=2,y=.5}, {mapID='1',x=.5,y=.5}}) do
  assert(not T.Allowed(bad));eq(T.Path(bad,p(1,2)),nil)
 end
 assert(not T.Segment(nil,p(1,2)));eq(T.Approach(nil),nil)
end)

test('terrain supercover rejects blocked corners and grid-boundary shortcuts',function()
 local T,p=fixture({'10','01'})
 assert(not T.Segment(p(1,1),p(2,2)));local path,reason=T.Path(p(1,1),p(2,2));eq(path,nil);eq(reason,'unreachable')
 T,p=fixture({'101','111','111'})
 assert(not T.Segment({mapID=1,x=0,y=1/3},{mapID=1,x=1,y=1/3}))
 assert(T.Segment(p(1,3),p(3,3)))
end)

test('terrain paths cross a ridge through its pass and keep normalized endpoints',function()
 local T,p=fixture({'11011','11011','11011','11111','11011'})
 local a,b=p(1,1),p(5,1);a.nodeKey='a';b.nodeKey='b'
 assert(not T.Segment(a,b));local path,length=T.Path(a,b);assert(path and #path>2)
 near(path[1].x,a.x);near(path[#path].y,b.y);assert(length>40)
 local total=0
 for i=2,#path do assert(T.Segment(path[i-1],path[i]));total=total+math.sqrt(((path[i].x-path[i-1].x)*50)^2+((path[i].y-path[i-1].y)*50)^2) end
 near(length,total);near(T.Distance(b,a),length)
 path[1].x=99;local again=T.Path(a,b);near(again[1].x,a.x)
end)

test('terrain approaches use nearby permitted cells within a yard bound',function()
 local T,p=fixture({'11111','11011','11111'})
 local blocked=p(3,2);eq(T.Approach(blocked,9),nil)
 local approach,reason=T.Approach(blocked,10);assert(approach and T.Allowed(approach));eq(reason,nil);near(T.Distance(approach,approach),0)
 assert(math.sqrt(((approach.x-blocked.x)*50)^2+((approach.y-blocked.y)*30)^2)<=10.00001)
 eq(blocked.x,.5);eq(T.Path(blocked,p(1,1)),nil)
end)

test('terrain distinguishes budget exhaustion from unreachable and does not cache failure',function()
 local T,p=fixture({'11011','11011','11011','11111','11011'})
 local path,reason=T.Path(p(1,1),p(5,1),{budget=0});eq(path,nil);eq(reason,'budget')
 assert(T.Path(p(1,1),p(5,1),{budget=1000}))
 T,p=fixture({'11011','11011','11011','11011','11011'})
 path,reason=T.Path(p(1,1),p(5,1));eq(path,nil);eq(reason,'unreachable')
end)

test('terrain periodically checkpoints bounded search and never yields inside pcall',function()
 local lines={};for y=1,81 do lines[y]=string.rep('1',40)..(y==81 and '1' or '0')..string.rep('1',40) end
 local T,p=fixture(lines);local calls=0
 T.Checkpoint=function() calls=calls+1;coroutine.yield() end
 local co=coroutine.create(function()
  local path,reason=T.Path(p(10,10),p(70,10),{budget=600});eq(path,nil);eq(reason,'budget')
 end)
 while coroutine.status(co)~='dead' do local ok,err=coroutine.resume(co);assert(ok,err) end
 eq(calls,2)
end)

test('terrain route expansion preserves gather identity and required closing bends',function()
 local T,p=fixture({'11011','11011','11011','11111','11011'})
 local a,b=p(1,1),p(5,1);a.kind='gather';a.nodeKey='a';a.id='one';b.kind='gather';b.nodeKey='b'
 local original={id='route',name='Ridge',loop=true,points={a,b}}
 assert(not T.Validate(original));local route=T.Route(original);assert(route and #route.points>4);eq(route.id,'route');eq(route.terrainVersion,1)
 assert(T.Validate(route));eq(#original.points,2);eq(original.terrainVersion,nil)
 local gathers=0;local before,after=false,false
 for _,point in ipairs(route.points) do
  if point.kind=='gather' then gathers=gathers+1;if point.nodeKey=='a' then eq(point.id,'one') end
  else assert(point.mandatory and point.navigation);if gathers==1 then before=true elseif gathers==2 then after=true end end
 end
 eq(gathers,2);assert(before and after)
end)

test('terrain validation checks closure and route expansion permits backtracking',function()
 local T,p=fixture({'11111','11011','11111'})
 local a,b,c=p(1,2),p(1,3),p(5,2)
 assert(T.Validate({loop=false,points={a,b}}));assert(not T.Validate({loop=true,points={a,b,c}}))
 local r=T.Route({loop=false,points={a,c,a}});assert(r and T.Validate(r));near(r.points[1].x,r.points[#r.points].x)
 eq(T.Validate({points={}}),false);eq(T.Route({points={}}),nil)
end)

test('terrain expansion preserves more than the historical 256 waypoints',function()
 local T,p=fixture({'11111111'})
 local route={loop=false,points={}}
 for i=1,300 do route.points[i]=p(i%8+1,1);route.points[i].nodeKey='n'..i;route.points[i].kind='gather' end
 local result=T.Route(route);assert(result);eq(#result.points,300);eq(result.points[300].nodeKey,'n300');assert(T.Validate(result))
end)

test('terrain rejects sparse routes and malformed map keys safely',function()
 local T,p=fixture({'11111'})
 local route={points={[1]=p(1,1),[3]=p(3,1)}}
 eq(T.Validate(route),false);eq(T.Route(route),nil)
 eq(T.Zone(nil),nil);eq(T.Zone(0/0),nil)
end)

test('terrain path cache keeps map identity when masks share a table',function()
 local T,p,A=fixture({'11011','11011','11111'})
 local a,b=p(1,1),p(5,1);assert(T.Path(a,b))
 A.TerrainData.zones[2]=A.TerrainData.zones[1];a.mapID=2;b.mapID=2
 local path=T.Path(a,b);assert(path);for _,waypoint in ipairs(path) do eq(waypoint.mapID,2) end
end)

test('terrain supercover stops at exact negative-going boundary endpoints',function()
 local T=fixture({'111','111','111'})
 local a={mapID=1,x=0,y=1/3};local b={mapID=1,x=2/3,y=0}
 assert(T.Segment(a,b));assert(T.Segment(b,a))
end)

test('terrain search observes a refreshed checkpoint after each coroutine resume',function()
 local lines={};for y=1,81 do lines[y]=string.rep('1',40)..(y==81 and '1' or '0')..string.rep('1',40) end
 local T,p=fixture(lines);local oldCalls,newCalls=0,0
 T.Checkpoint=function() oldCalls=oldCalls+1;coroutine.yield() end
 local co=coroutine.create(function() local path,reason=T.Path(p(10,10),p(70,10),{budget=600});eq(path,nil);eq(reason,'budget') end)
 assert(coroutine.resume(co));eq(oldCalls,1)
 T.Checkpoint=function() newCalls=newCalls+1;coroutine.yield() end
 while coroutine.status(co)~='dead' do local ok,err=coroutine.resume(co);assert(ok,err) end
 eq(oldCalls,1);eq(newCalls,1)
end)

test('terrain long direct validation also checkpoints the generation frame budget',function()
 local T,p=fixture({string.rep('1',1024)});local calls=0
 T.Checkpoint=function() calls=calls+1;coroutine.yield() end
 local co=coroutine.create(function() assert(T.Segment(p(1,1),p(1024,1))) end)
 while coroutine.status(co)~='dead' do local ok,err=coroutine.resume(co);assert(ok,err) end
 assert(calls>=3,'Direct mask traversal must share the generation budget')
end)

test('terrain rectangular-cell detours fit the bounded search budget',function()
 local lines={};for y=1,81 do lines[y]=string.rep('1',40)..(y==81 and '1' or '0')..string.rep('1',40) end
 local T,p=fixture(lines,810,1620)
 local path,reason=T.Path(p(10,10),p(70,10),{budget=4300})
 assert(path,'A safe pass should be found within 4300 expansions: '..tostring(reason))
 assert(T.Validate({points=path}))
end)

test('terrain row decoding rejects unknown bytes and observes replaced masks',function()
 local T,p,A=fixture({'1111111','1111111'})
 local z=A.TerrainData.zones[1]
 for n=0,255 do
  z.rows[1]=string.char(n)..'g'
  local value=alphabet:find(string.char(n),1,true)
  for x=1,6 do
   local expected=value~=nil and math.floor((value-1)/2^(6-x))%2==1
   eq(T.Allowed(p(x,1)),expected)
  end
  assert(T.Allowed(p(7,1)))
 end
 z.rows[1]='';assert(not T.Allowed(p(1,1)))
 z.rows[1]='/g';assert(T.Allowed(p(1,1)))
 z.rows[1]='Ag';assert(not T.Allowed(p(1,1)))
 local replacement={w=7,h=2,widthYards=70,heightYards=20,rows={'/g','/g'},status='complete'}
 A.TerrainData.zones[1]=replacement;assert(T.Allowed(p(1,1)))
end)

test('terrain retains useful detours across a complete local planning graph',function()
 local lines={};for y=1,5 do lines[y]=string.rep('1',25)..(y==5 and '1' or '0')..string.rep('1',25) end
 local T,p=fixture(lines);local a,b=p(1,1),p(51,1);assert(T.Path(a,b))
 for i=1,180 do assert(T.Path(p(2+i%20,1+math.floor(i/20)%4),p(31+math.floor(i/20)%20,1+i%4))) end
 local path,reason=T.Path(a,b,{budget=0});assert(path,'A retained valid detour should not be searched again: '..tostring(reason))
 assert(T.Validate({points=path}));path[1].x=.5
 local again=assert(T.Path(a,b,{budget=0}));near(again[1].x,a.x)
end)

test('fully searched unreachable pairs are reusable but budget failures are not cached',function()
 local T,p=fixture({'11011','11011','11011'})
 local a,b=p(1,1),p(5,1);local path,reason=T.Path(a,b);eq(path,nil);eq(reason,'unreachable')
 path,reason=T.Path(a,b,{budget=0});eq(path,nil);eq(reason,'unreachable')
 T,p=fixture({'11011','11011','11111'});a,b=p(1,1),p(5,1)
 path,reason=T.Path(a,b,{budget=0});eq(path,nil);eq(reason,'budget');assert(T.Path(a,b))
end)

test('terrain result caches invalidate when an existing zone mask changes',function()
 local T,p,A=fixture({'11011','11011','11011'})
 local a,b=p(1,1),p(5,1);local path,reason=T.Path(a,b);eq(path,nil);eq(reason,'unreachable')
 local z=A.TerrainData.zones[1];z.rows[3]='+'
 path,reason=T.Path(a,b);assert(path,reason);assert(T.Validate({points=path}))
 z.rows[3]='2';path,reason=T.Path(a,b);eq(path,nil);eq(reason,'unreachable')
end)
