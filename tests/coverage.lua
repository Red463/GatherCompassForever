local function planner()
 local A={}
 module('Store',A)
 module('Coverage',A)
 module('Planner',A)
 return A
end
local function yards(x,y,key)
 return {mapID=1,x=x/1000,y=y/500,key=key,kind='herb',materialID='earthroot',name='Earthroot'}
end
-- Independent oracle based on along-track and perpendicular distances in yards.
local function separation(node,points,metric)
 local best=math.huge
 for i,a in ipairs(points) do
  local b=points[i%#points+1]
  local ab,ap,bp=metric(a,b),metric(a,node),metric(b,node)
  local d=math.min(ap,bp)
  if ab>0 then
   local along=(ap*ap+ab*ab-bp*bp)/(2*ab)
   if along>0 and along<ab then d=math.sqrt(math.max(0,ap*ap-along*along)) end
  end
  best=math.min(best,d)
 end
 return best
end
local function audit(route,legacy,nodes,metric)
 local count=0
 for _,n in ipairs(nodes) do
  local covered=separation(n,route.points,metric)<=route.coverageRadius+.000001
  eq(not not route.includedKeys[n.key],covered)
  if legacy.includedKeys[n.key] then assert(covered,'Lost local candidate '..n.key) end
  if covered then count=count+1 end
 end
 eq(route.includedCount,count);eq(route.omittedCount,#nodes-count)
 eq(route.points[1].nodeKey,legacy.points[1].nodeKey)
 for i,p in ipairs(route.points) do
  assert(metric(p,route.points[i%#route.points+1])<=450.000001,'Long leg or closure')
  eq(p.kind,'travel');eq(p.name,'Farming corridor');eq(p.materialID,nil);eq(p.resourceKind,nil)
 end
end

test('yard-space coverage includes closure, clamped endpoints and inclusive boundaries',function()
 local A=planner();assert(A.Coverage,'Missing yard-space coverage')
 local path={{x=0,y=0},{x=300,y=0},{x=300,y=400}}
 local index=A.Coverage.ClosedIndex(path,10)
 assert(index:Find({x=150,y=200}),'Closing diagonal was missed')
 assert(index:Find({x=120,y=10}));assert(not index:Find({x=120,y=10.001}))
 assert(index:Find({x=-6,y=-8}));assert(not index:Find({x=-6,y=-8.001}))
 local single=A.Coverage.ClosedIndex({path[1]},5)
 assert(single:Find({x=3,y=4}));assert(not single:Find({x=-5.001,y=0}))
 local coincident=A.Coverage.ClosedIndex({path[1],path[1]},5)
 assert(coincident:Find({x=0,y=5}));assert(not coincident:Find({x=0,y=5.001}))
end)

test('corridor keeps its entry and removes off-centre gather stops on a rectangular map',function()
 local A=planner()
 local nodes={yards(100,100,'entry'),yards(230,130,'side'),yards(360,100,'middle'),yards(490,100,'end')}
 local legacy=A.Planner.Generate(nodes,nodes[1],distance)
 local r=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=40,viewRadius=45})
 eq(r.corridor,true);eq(r.minimapViewRadius,45);eq(r.coverageRadius,40);eq(r.heatRadius,26)
 near(r.heatSpacing,15.6)
 audit(r,legacy,nodes,distance)
 eq(#r.points,2);assert(#r.points<#legacy.points)
 assert(separation(nodes[2],r.points,distance)>r.heatRadius,'Off-centre fixture sits inside paint')
end)

test('grouped outliers wider than the corridor retain a short approach',function()
 local A=planner()
 local nodes={yards(5,5,'entry'),yards(115,115,'outlier'),yards(5,5,'same coordinates')}
 local legacy=A.Planner.Generate(nodes,nodes[1],distance);eq(#legacy.points,1);eq(legacy.includedCount,3)
 local r=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=10,viewRadius=12})
 assert(#r.points>1,'Legacy representative alone misses a required identity')
 audit(r,legacy,nodes,distance)
end)

test('single-anchor corridor counts additional eligible candidates by yard distance independently of group membership',function()
 local A=planner()
 local nodes={yards(10,200,'anchor'),yards(500,200,'inside'),yards(950,450,'outside')}
 local legacy=A.Planner.Generate(nodes,nodes[1],distance);eq(legacy.includedCount,1)
 local r=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=500,viewRadius=555})
 eq(r.includedCount,2);eq(#r.points,1);audit(r,legacy,nodes,distance)
 local excluded=A.Planner.Generate({nodes[1],nodes[3]},nodes[1],distance,{coverageRadius=500})
 eq(excluded.includedCount,1);eq(excluded.includedKeys.inside,nil)
end)

test('dense corridor preserves every old identity and bounds native distance calls',function()
 local A=planner();local nodes={}
 for i=1,5000 do nodes[i]=yards((i%100)*10,math.floor(i/100)*9,tostring(i)) end
 local legacy=A.Planner.Generate(nodes,nodes[1],distance);local calls=0
 local function measured(a,b) calls=calls+1;return distance(a,b) end
 local r=A.Planner.Generate(nodes,nodes[1],measured,{coverageRadius=50,viewRadius=56})
 eq(r.corridor,true);audit(r,legacy,nodes,distance)
 assert(calls<18000,'Repeated native candidate/segment distances: '..calls)
 assert(#r.points<96,'Dense corridor failed to reduce local navigation')
end)
test('unreadable corridor radius fails without generating legacy gather stops',function()
 local A=planner();local nodes={yards(50,50,'a')}
 for _,bad in ipairs({false,0,-1,math.huge,0/0,'50'}) do
  local r,reason=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=bad})
  eq(r,nil);assert(type(reason)=='string')
 end
end)
test('corridor rejects a baseline edge that exceeds the yard connection limit after calibration',function()
 local A=planner();local nodes={yards(50,50,'a'),yards(800,50,'b')}
 local function inconsistent(a,b)
  if a.x==0 and a.y==0 then return distance(a,b) end
  return distance(a,b)/2
 end
 local r,message=A.Planner.Generate(nodes,nodes[1],inconsistent,{coverageRadius=10})
 eq(r,nil);assert(type(message)=='string')
end)
test('narrow heat bands require enough samples for the entire closing leg',function()
 local A=planner();local nodes={yards(50,50,'a'),yards(450,50,'b')}
 local r,reason=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=.4})
 eq(r,nil);assert(reason:find('heat band'))
 assert(A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=.51}))
end)

test('excessive repair detail fails before publishing more stops than the maps can draw',function()
 local A=planner();local nodes={};local seed=7
 local function rng() seed=seed*16807%2147483647;return seed/2147483647 end
 for i=1,480 do nodes[i]=yards(5+rng()*110,5+rng()*110,tostring(i)) end
 local r,reason=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=.1})
 eq(r,nil);assert(reason:find('guidance stops'))
end)
