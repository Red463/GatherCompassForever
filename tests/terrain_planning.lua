local function terrainPlanner(zones)
 local A={TerrainData={version=1,zones=zones or {}}}
 module('Store',A);module('Terrain',A);module('Planner',A)
 return A
end
local function terrainNode(x,y,key)
 return {mapID=1,x=x,y=y,key=key,kind='herb',materialID='earthroot',name='Earthroot'}
end
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function fixture(blocked,w,h,width,height)
 w,h=w or 25,h or 15
 local rows={}
 for y=1,h do
  local row=''
  for x=1,w,6 do
   local bits=0
   for j=0,5 do bits=bits*2+((x+j<=w and not blocked(x+j,y)) and 1 or 0) end
   row=row..alphabet:sub(bits+1,bits+1)
  end
  rows[y]=row
 end
 return {[1]={w=w,h=h,widthYards=width or 1000,heightYards=height or 600,rows=rows,status='complete'}}
end
local function safeGeometry(route,blocked)
 for i,a in ipairs(route.points) do
  local b=route.points[i%#route.points+1]
  for j=0,200 do
   local t=j/200
   local x=math.min(25,math.floor((a.x+(b.x-a.x)*t)*25)+1)
   local y=math.min(15,math.floor((a.y+(b.y-a.y)*t)*15)+1)
   assert(not blocked(x,y),'Guidance crossed blocked terrain, including closure')
  end
 end
end

test('production planner fails closed when zone terrain is absent',function()
 -- A production Terrain object may never fall back to the old straight lines.
 local A={Terrain={Zone=function() return nil,'unavailable' end}}
 module('Store',A);module('Planner',A)
 local node=terrainNode(.2,.5,'near')
 local route,reason=A.Planner.Generate({node},node,distance,{coverageRadius=30})
 eq(route,nil);assert(type(reason)=='string')
end)

test('walking connection limits omit close nodes when their ridge detour exceeds 450 yards',function()
 local function blocked(x,y) return x==13 and y~=1 end
 local A=terrainPlanner(fixture(blocked))
 local nodes={terrainNode(.46,.7,'left'),terrainNode(.54,.7,'right')}
 local route,reason=A.Planner.Generate(nodes,nodes[1],distance)
 assert(route,reason);eq(route.includedCount,1);eq(route.includedKeys.right,nil)
 safeGeometry(route,blocked)
end)

test('fine terrain bends survive the old 256 stop and narrow heat sampling limits',function()
 local function blocked(x,y)
  if y%2==1 then return false end
  return x~=(y%4==2 and 5 or 1)
 end
 local A=terrainPlanner(fixture(blocked,5,281,2,100))
 local nodes={terrainNode(.1,.5/281,'first'),terrainNode(.9,280.5/281,'last')}
 local route,reason=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=.01})
 assert(route,reason);eq(route.includedCount,2)
 assert(#route.points>256,'Fixture must need fine mandatory navigation')
 assert(A.Terrain.Validate(route),'Fine terrain route was truncated or shortcut')
 assert(route.heatSpacing>A.Coverage.HeatSpacing(route.heatRadius),'Heat detail should adapt independently of navigation')
end)

test('generated corridor follows a ridge pass and omits a mountain spawn without a safe approach',function()
 local function blocked(x,y) return x==13 and y~=4 or x>=11 and x<=15 and y>=10 end
 local A=terrainPlanner(fixture(blocked))
 local nodes={terrainNode(.42,6.5/15,'left'),terrainNode(.58,6.5/15,'right'),terrainNode(.5,12.5/15,'mountain')}
 local route,reason=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=35})
 assert(route,reason);eq(route.terrainVersion,1);eq(route.corridor,true)
 assert(route.includedKeys.left and route.includedKeys.right,'Reachable farming side was lost')
 eq(route.includedKeys.mountain,nil);eq(route.omittedCount,1)
 assert(#route.points>2,'Ridge pass needs mandatory bends')
 safeGeometry(route,blocked)
 for _,p in ipairs(route.points) do assert(p.mandatory,'Terrain geometry must survive later optimizers') end
end)

test('same-cell spawn groups and minimap coverage never claim through a sealed ridge',function()
 local function blocked(x) return x==12 end
 local A=terrainPlanner(fixture(blocked))
 local nodes={terrainNode(.415,.5,'left'),terrainNode(.495,.5,'right')}
 local route,reason=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=180})
 assert(route,reason);eq(route.includedCount,1);eq(route.includedKeys.right,nil)
 safeGeometry(route,blocked)
end)

test('one close node across a sealed ridge does not exhaust generation for a reachable farming area',function()
 local A=terrainPlanner(fixture(function(x) return x==201 end,400,240,400*25/6,240*25/6))
 local nodes={terrainNode(.49,.5,'near'),terrainNode(.51,.5,'other-side')}
 local route,reason=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=180})
 assert(route,reason);eq(route.includedCount,1);eq(route.includedKeys['other-side'],nil)
 assert(A.Terrain.Validate(route))
end)

test('generation propagates path budgets instead of describing them as disconnected nodes',function()
 local A={Terrain={Zone=function() return {widthYards=1000,heightYards=600} end,
  Approach=function(p) return p end,Path=function() return nil,'budget' end}}
 module('Store',A);module('Planner',A)
 local node=terrainNode(.2,.5,'near')
 local route,reason=A.Planner.Generate({node},node,distance,{coverageRadius=30})
 eq(route,nil);assert(reason:find('budget'))
end)

test('coverage counts original visible spawns rather than an approach outside the minimap band',function()
 local A=terrainPlanner(fixture(function(x) return x==51 end,100,10,1000,100))
 local nodes={terrainNode(.495,.55,'anchor'),terrainNode(.505,.55,'blocked')}
 local route,reason=A.Planner.Generate(nodes,nodes[1],distance,{coverageRadius=5})
 assert(route,reason);eq(route.includedCount,1);eq(route.includedKeys.blocked,nil)
end)
