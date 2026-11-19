test('planner respects map and clustered materials and handles zero or one point',function()
 local A={}; module('Store',A); module('Planner',A)
 eq(A.Planner.Generate({},point(.1),distance),nil)
 local a=point(.2); a.key='one'; a.materialID='herb'; local b=point(.205); b.key='two'; b.materialID='herb'
 local c=point(.4); c.mapID=2
 local r=A.Planner.Generate({a,b,c},point(.1),distance); eq(#r.points,1); eq(r.generated,true); eq(r.loop,true)
end)

test('generated names describe actual resources and zone with concise profession fallbacks',function()
 local A={};module('Store',A);module('Resources',A);module('Planner',A)
 local function node(x,id,name,kind,map)
  return {mapID=map or 1,x=x,y=.5,materialID='gm:'..(kind or 'herb')..':'..id,name=name,kind=kind or 'herb',key=tostring(x)}
 end
 local a=node(.2,402,'Silverleaf');local b=node(.3,403,'Earthroot');local c=node(.4,401,'Peacebloom')
 local function name(nodes) return A.Planner.Generate(nodes,point(.1),distance,{zoneName='Elwynn Forest'}).name end
 eq(name({a}),'Elwynn Forest - Silverleaf Loop')
 eq(name({a,b}),'Elwynn Forest - Earthroot & Silverleaf Loop')
 eq(name({a,b,c}),'Elwynn Forest - Herbalism Loop')
 eq(name({a,node(.4,201,'Copper Vein','ore')}),'Elwynn Forest - Herbs & Ore Loop')
 eq(name({a,node(.4,201,'Copper Vein','ore',2)}),'Elwynn Forest - Silverleaf Loop')
 eq(A.Planner.Generate({a},point(.1),distance).name,'Zone 1 - Silverleaf Loop')
 eq(A.Planner.Generate({a},point(.1),distance,{name='My own name'}).name,'My own name')
end)

test('automatic names remain saveable and disambiguate existing names without changing them',function()
 local A={};module('Store',A);module('Resources',A);module('Planner',A)
 local node={mapID=1,x=.2,y=.5,materialID='gm:herb:403',name='Earthroot',kind='herb',key='one'}
 local routes={r1={name='elwynn forest - earthroot loop'},r2={name='Elwynn Forest - Earthroot Loop (2)'}}
 local route=A.Planner.Generate({node},point(.1),distance,{zoneName='Elwynn Forest',routes=routes})
 eq(route.name,'Elwynn Forest - Earthroot Loop (3)');eq(routes.r1.name,'elwynn forest - earthroot loop')
 local long=string.rep('森',40);route=A.Planner.Generate({node},point(.1),distance,{zoneName=long})
 assert(#route.name<=80);assert(A.Store.SaveRoute(A.Store.Open(),route),'Automatic name must pass route validation')
 assert(route.name:sub(-5)==' Loop');local prefix=route.name:match('^(.-) %-')
 assert(prefix and #prefix%3==0,'Zone prefix cut inside a UTF-8 character')
end)
test('generation bounds quadratic work before clustering and optimization',function()
 local A={}; module('Store',A); module('Planner',A); local nodes={}; local calls=0
 for i=1,5000 do local p=point((i%100)/100,math.floor(i/100)/100); p.key=tostring(i); p.materialID='x'; nodes[i]=p end
 local r,warning=A.Planner.Generate(nodes,point(.1),function(a,b) calls=calls+1; return distance(a,b) end)
 assert(#r.points<=192);assert(r.areaCount<=96);assert(warning:find('Local corridor'));assert(calls<180000,'unbounded work: '..calls)
end)

test('local corridor fixes the reproduced nearest-then-distant second waypoint and bounds every leg',function()
 local A={};for _,name in ipairs({'Store','Planner','Follower'}) do module(name,A) end
 local seed=15;local function rng() seed=(seed*16807)%2147483647;return seed/2147483647 end
 local start={mapID=1,x=.2,y=.8};local nodes={{mapID=1,x=.2,y=.8,materialID='herb',kind='herb',key='n0'}}
 for i=1,223 do nodes[#nodes+1]={mapID=1,x=.05+rng()*.9,y=.05+rng()*.9,materialID='herb',kind='herb',key='n'..i} end
 local function d(a,b) return math.sqrt(((a.x-b.x)*6000)^2+((a.y-b.y)*4000)^2) end
 local r=A.Planner.Generate(nodes,start,d);local f=A.Follower.New(r,start,d,{arrival=15});f:Tick(start,0,false)
 assert(d(start,f:Target())<=450,'First outgoing leg still crosses the zone')
 assert(#r.points<=192);assert(r.includedCount and r.omittedCount)
 for i,p in ipairs(r.points) do assert(d(p,r.points[i%#r.points+1])<=450.00001,'Route or closing leg exceeds the connection limit') end
end)

test('generation keeps the nearest candidate beyond old input cap and leaves disconnected regions out',function()
 local A={};module('Store',A);module('Planner',A)
 local nodes={};for i=1,301 do nodes[i]={mapID=1,x=.9,y=.5,kind='herb',materialID='herb',key='far'..i} end
 nodes[302]={mapID=1,x=.1,y=.5,kind='herb',materialID='herb',key='near'}
 local r=A.Planner.Generate(nodes,point(.1),distance);assert(r and r.points[1].nodeKey=='near');eq(r.includedCount,1);eq(r.omittedCount,301)
 eq(A.Planner.Generate({nodes[1]},point(.1),distance),nil)
end)

local function circuitMetrics(route,distance)
 local length,crossings,gathers=0,0,{}
 local points=route.points
 local function side(a,b,c) return (b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x) end
 for i,a in ipairs(points) do
  local b=points[i%#points+1];local d=distance(a,b)
  assert(d<=450.00001,'Optimized route has a long outgoing or closing leg');length=length+d
  if a.kind=='gather' then assert(not gathers[a.nodeKey],'Duplicate gather stop');gathers[a.nodeKey]=true end
  for j=i+1,#points do
   local c,e=points[j],points[j%#points+1]
   if side(a,b,c)*side(a,b,e)<-1e-15 and side(c,e,a)*side(c,e,b)<-1e-15 then
    assert(distance(a,c)>450 or distance(b,e)>450,'A crossing still has a valid short uncrossing')
    crossings=crossings+1
   end
  end
 end
 local count=0;for _ in pairs(gathers) do count=count+1 end
 return length,crossings,count,gathers
end

for _,fixture in ipairs({{15,31932,2,83,92},{29,35950,6,94,101},{47,38000,6,95,101}}) do
 test('circuit optimization reduces travel and crossings without losing farming areas for seed '..fixture[1],function()
  local A={};module('Store',A);module('Planner',A)
  local seed=fixture[1];local function rng() seed=(seed*16807)%2147483647;return seed/2147483647 end
  local start={mapID=1,x=.2,y=.8};local nodes={{mapID=1,x=.2,y=.8,kind='herb',materialID='herb',key='n0'}}
  for i=1,223 do nodes[#nodes+1]={mapID=1,x=.05+rng()*.9,y=.05+rng()*.9,kind='herb',materialID='herb',key='n'..i} end
  local function d(a,b) return math.sqrt(((a.x-b.x)*6000)^2+((a.y-b.y)*4000)^2) end
  local route=A.Planner.Generate(nodes,start,d);local length,crossings,gathers=circuitMetrics(route,d)
  assert(length<fixture[2]*.9,'Circuit still takes '..length..' yards')
  assert(crossings<=fixture[3],'Optimization added crossings: '..crossings)
  eq(route.areaCount,fixture[4]);eq(gathers,fixture[4]);eq(route.includedCount,fixture[5]);eq(route.points[1].nodeKey,'n0')
  for _,p in ipairs(route.points) do eq(p.resourceKind,'herb');eq(p.materialID,'herb');assert(route.includedKeys[p.nodeKey]) end
  local again=A.Planner.Generate(nodes,start,d);eq(#again.points,#route.points)
  for i,p in ipairs(route.points) do eq(again.points[i].nodeKey,p.nodeKey);eq(again.points[i].kind,p.kind) end
 end)
end

test('circuit optimization preserves the necessary return path through a narrow hub',function()
 local A={};module('Store',A);module('Planner',A)
 local nodes={};for i,p in ipairs({{.5,.5},{.1,.5},{.9,.5},{.5,.1},{.5,.9}}) do nodes[i]={mapID=1,x=p[1],y=p[2],kind='herb',materialID='herb',key='n'..i} end
 local function d(a,b) return math.sqrt(((a.x-b.x)*1000)^2+((a.y-b.y)*1000)^2) end
 local route=A.Planner.Generate(nodes,nodes[1],d);local length,_,count,gathers=circuitMetrics(route,d)
 near(length,3200);eq(count,5);eq(route.areaCount,5);eq(#route.points,8)
 for i=1,5 do assert(gathers['n'..i],'Necessary farming branch was dropped') end
end)
