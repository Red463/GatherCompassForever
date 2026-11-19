test('recorded path simplifies straight samples but retains a corner',function()
 local A={}; module('Store',A); module('Recorder',A)
 local r=A.Recorder.New(1,distance); r:Sample(point(.1,.1),0); r:Sample(point(.12,.1),1); r:Sample(point(.14,.1),2); r:Sample(point(.14,.15),3)
 local route=assert(r:Finish('Walk')); eq(#route.points,3); near(route.points[2].x,.14); near(route.points[2].y,.1)
end)
test('recording curve simplification bounds error for every original sample',function()
 local A={}; module('Store',A); module('Recorder',A); local r=A.Recorder.New(1,distance)
 local originals={}
 for i=0,20 do
  local theta=i/20*math.pi/2; local p=point(.5+80*math.cos(theta)/1000,.5+80*math.sin(theta)/500)
  originals[#originals+1]=p; r:Sample(p,i)
 end
 local path=assert(r:Finish('Curve')).points
 for _,p in ipairs(originals) do
  local best=math.huge
  for i=1,#path-1 do
   local a,b=path[i],path[i+1]; local ab=distance(a,b); local ap,bp=distance(a,p),distance(b,p)
   local t=math.max(0,math.min(1,(ap*ap+ab*ab-bp*bp)/(2*ab*ab)))
   local q=point(a.x+(b.x-a.x)*t,a.y+(b.y-a.y)*t); best=math.min(best,distance(p,q))
  end
  assert(best<=3.0001,'Curve cut by '..best..' yards')
 end
end)
test('recording discontinuity pauses and cannot bridge separated points',function()
 local A={}; module('Store',A); module('Recorder',A)
 local r=A.Recorder.New(1,distance); r:Sample(point(.1),0); r:Sample(nil,1); r:Sample(point(.8),2)
 eq(#r.points,1); eq(r.paused,true); eq(r:Resume(point(.8)),false); eq(r:Resume(point(.1)),true)
 r:Sample(point(.12),4); eq(#assert(r:Finish('Walk')).points,2)
end)
