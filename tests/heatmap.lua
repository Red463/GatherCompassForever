test('heat corridor is bounded continuous cached and does not count backtracking twice',function()
 dofile('tests/wow.lua');fakeUI();local A={};module('Heatmap',A)
 local a=point(.1);a.density=8;local b=point(.2);b.density=2
 local r={mapID=1,width=10000,height=5000,points={a,b,a},loop=true}
 local samples=A.Heatmap.Samples(r);assert(#samples>=10 and #samples<=512)
 local two=A.Heatmap.Samples({mapID=1,width=10000,height=5000,points={a,b}});eq(#samples,#two);eq(A.Heatmap.Samples(r),samples)
 local maxGap=0;for i=2,#samples do maxGap=math.max(maxGap,math.abs(samples[i].x-samples[i-1].x)*10000) end
 assert(maxGap<=samples.radius);assert(samples.radius>=100)
 local pool={};A.Heatmap.Draw(pool,UIParent,r,function(p) return p.x*1000,-p.y*500 end,function(radius) return radius/10,radius/10 end)
 assert(#pool>0 and #pool<=512);A.Heatmap.Hide(pool);eq(pool[1]:IsShown(),false)
end)
test('heat corridor sample budget holds for dense large routes',function()
 local A={};module('Heatmap',A);local points={};for i=1,192 do points[i]=point(i/193,math.sin(i)*.4+.5) end
 local samples=A.Heatmap.Samples({mapID=1,width=10000,height=10000,loop=true,points=points});assert(#samples<=512);assert(#samples>0)
 for _,p in ipairs(points) do local near=false;for _,s in ipairs(samples) do if math.abs(p.x-s.x)*10000<36 and math.abs(p.y-s.y)*10000<36 then near=true;break end end;assert(near,'Heat corridor lost a route endpoint') end
end)

test('heat palette remains dark red',function()
 dofile('tests/wow.lua');fakeUI();local A={};module('Heatmap',A)
 local route={width=1000,height=500,points={point(.2),point(.6)},loop=true};local pool={}
 A.Heatmap.Draw(pool,UIParent,route,function(p) return p.x*1000,0 end,function(r) return r,r end)
 for _,t in ipairs(pool) do assert(t.vertexColor[1]<.9 and t.vertexColor[2]<.5) end
end)

test('bounded terrain heat sampling includes the tail of routes with thousands of mandatory bends',function()
 local A={};module('Heatmap',A)
 local points={}
 for i=0,5999 do points[#points+1]={mapID=1,x=i/5999,y=.5+(i%2)*.0001,mandatory=true} end
 local route={mapID=1,width=12000,height=6000,terrainVersion=1,corridor=true,heatRadius=2,heatSpacing=1.2,points=points}
 local samples=A.Heatmap.Samples(route)
 assert(#samples<=4096 and #samples>0)
 local first,last=false,false
 for _,p in ipairs(samples) do
  first=first or p.x<.0001;last=last or p.x>.9999
  -- Each stamp must remain on the actual bent geometry, rather than a chord
  -- between sparsely retained navigation points.
  local at=math.min(5998,math.floor(p.x*5999));local t=p.x*5999-at
  local expected=.5+((at%2)*(1-t)+((at+1)%2)*t)*.0001
  near(p.y,expected)
 end
 assert(first and last,'Heat budget cropped the beginning or tail of the route')
 eq(#route.points,6000);assert(points[6000].mandatory)
end)
