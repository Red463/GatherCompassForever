local function setup()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Follower','Map'}) do module(name,A) end
 A.Client.Position=function() return point(.1) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance;A.Client.Facing=function() return 0 end
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end;GetMinimapShape=function() return 'ROUND' end
 local db=A.Store.Open();local s=A.Resources.Settings(db.settings)
 s.worldLineOpacity=1;s.worldHeatOpacity=1;s.miniLineOpacity=1;s.miniHeatOpacity=1
 local route={mapID=1,width=1000,height=500,points={point(.2),point(.3)},loop=true}
 local follower=A.Follower.New(route,point(.1),distance)
 return A,db,s,route,follower
end

test('map line opacity scales world shadows and minimap strokes independently without changing guidance',function()
 local A,db,s,route,f=setup();A.Map.Refresh(db,route,f)
 local world,shadow,mini=A.Map.worldLines[1].color[4],A.Map.worldShadows[1].color[4],A.Map.miniLines[1].color[4]
 local target=f:Target();s.worldLineOpacity=.2;s.miniLineOpacity=.4;A.Map.Refresh(db,route,f)
 near(A.Map.worldLines[1].color[4],world*.2);near(A.Map.worldShadows[1].color[4],shadow*.2);near(A.Map.miniLines[1].color[4],mini*.4)
 eq(f:Target(),target);s.worldLineOpacity=0;A.Map.Refresh(db,route,f)
 eq(A.Map.worldLines[1]:IsShown(),false);assert(A.Map.miniLines[1]:IsShown())
 C_Minimap=nil;GetCVar=nil;GetMinimapShape=nil
end)

test('heat opacity is independent of lines and map surface and zero hides only its overlay',function()
 local A,db,s,route,f=setup();db.settings.routeStyle='heatmap';A.Map.Refresh(db,route,f)
 local function heatAlpha() local t=A.Map.worldHeat[1];return t.vertexColor[4]*t:GetAlpha() end
 local world,mini=heatAlpha(),A.Map.miniHeat[1].color[4]
 s.worldHeatOpacity=.3;s.miniHeatOpacity=.5;s.worldLineOpacity=0;s.miniLineOpacity=0;A.Map.Refresh(db,route,f)
 near(heatAlpha(),world*.3);near(A.Map.miniHeat[1].color[4],mini*.5)
 s.miniHeatOpacity=0;A.Map.Refresh(db,route,f);eq(A.Map.miniHeat[1]:IsShown(),false);assert(A.Map.worldHeat[1]:IsShown())
 s.worldHeatOpacity=0;A.Map.Refresh(db,route,f);eq(A.Map.worldHeat[1]:IsShown(),false);eq(f.status,'running')
 C_Minimap=nil;GetCVar=nil;GetMinimapShape=nil
end)

test('saved minimap heat colour reaches actual map rendering without recolouring world heat or changing guidance',function()
 local A,db,s,route,f=setup();db.settings.routeStyle='heatmap';A.Map.Refresh(db,route,f)
 local world=A.Store.Copy(A.Map.worldHeat[1].vertexColor);local alpha=A.Map.miniHeat[1].color[4];local target=f:Target()
 s.miniHeatColour='cyan';A.Map.Refresh(db,route,f)
 local mini=A.Map.miniHeat[1].color;near(mini[1],.1);near(mini[2],.9);near(mini[3],1);near(mini[4],alpha)
 for i=1,4 do near(A.Map.worldHeat[1].vertexColor[i],world[i]) end;eq(f:Target(),target);eq(f.status,'running')
 C_Minimap=nil;GetCVar=nil;GetMinimapShape=nil
end)

test('minimap route palette recolours every line while preserving opacity world colours and guidance',function()
 local A,db,s,route,f=setup();A.Map.Refresh(db,route,f)
 local world=A.Store.Copy(A.Map.worldLines[1].color)
 local alpha,width=A.Map.miniLines[1].color[4],A.Map.miniLines[1].thickness
 local target=f:Target()
 for _,choice in ipairs({{'cyan',.1,.9,1},{'pink',1,.3,.85},{'green',.3,1,.25},{'white',1,1,1},{'yellow',1,.95,.1},{'amber',1,.6,.06}}) do
  s.miniHeatColour=choice[1];A.Map.Refresh(db,route,f)
  local count=0
  for _,stroke in ipairs(A.Map.miniLines) do if stroke:IsShown() then
   count=count+1;for i=1,3 do near(stroke.color[i],choice[i+1]) end
  end end
  assert(count>0);near(A.Map.miniLines[1].color[4],alpha);near(A.Map.miniLines[1].thickness,width)
  for i=1,4 do near(A.Map.worldLines[1].color[i],world[i]) end
  eq(f:Target(),target);eq(f.status,'running')
 end
 s.miniHeatColour='cyan';db.settings.routeStyle='heatmap';A.Map.Refresh(db,route,f)
 near(A.Map.miniHeat[1].color[1],.1);near(A.Map.miniHeat[1].color[2],.9)
 db=A.Store.Open(A.Store.Copy(db));db.settings.routeStyle='lines'
 A.Resources.Settings(db.settings).miniLineOpacity=.4;A.Map.Refresh(db,route,f)
 local mini=A.Map.miniLines[1].color;near(mini[1],.1);near(mini[2],.9);near(mini[3],1);near(mini[4],alpha*.4)
 C_Minimap=nil;GetCVar=nil;GetMinimapShape=nil
end)

test('corridor paint radius is narrower than coverage and fixed independently of opacity',function()
 local A={};module('Heatmap',A)
 local route={mapID=1,width=1000,height=500,coverageRadius=180,heatRadius=117,corridor=true,points={point(.2),point(.6)}}
 local samples=A.Heatmap.Samples(route);near(samples.radius,117);assert(samples.radius<route.coverageRadius)
end)

test('long corridor paint keeps a continuous narrow band through every guidance leg',function()
 local A={};module('Heatmap',A)
 local points={}
 local function add(x,y) points[#points+1]={mapID=1,x=x/6000,y=y/4000} end
 for row=0,7 do for col=0,14 do local x=row%2==0 and 300+col*5400/14 or 5700-col*5400/14;add(x,400+row*400) end end
 for row=6,1,-1 do add(300,400+row*400) end
 local route={corridor=true,heatRadius=117,coverageRadius=180,width=6000,height=4000,loop=true,points=points}
 local samples=A.Heatmap.Samples(route);assert(#samples<=4096)
 for i,a in ipairs(points) do
  local b=points[i%#points+1];local x,y=(a.x+b.x)/2,(a.y+b.y)/2;local nearest=math.huge
  for _,p in ipairs(samples) do nearest=math.min(nearest,math.sqrt(((p.x-x)*6000)^2+((p.y-y)*4000)^2)) end
  assert(nearest<=117*.35,'Heat paint has a weak or missing corridor section: '..nearest)
 end
end)

test('unrepresentable heat bins fail within a bounded instruction count',function()
 local A={};module('Heatmap',A)
 local route={corridor=true,width=1000,height=500,heatRadius=6.5e-16,points={point(.5)}}
 local ticks=0;debug.sethook(function() ticks=ticks+1;if ticks>100 then error('Heat loop exceeded instruction budget') end end,'',1000)
 local ok,samples=pcall(A.Heatmap.Samples,route);debug.sethook()
 assert(ok,tostring(samples));eq(#samples,0);eq(samples.invalid,true)
end)

test('terrain map drawing preserves every bend instead of striding across restrictions',function()
 local A,db,s,route=setup();route.terrainVersion=1;route.loop=false;route.points={}
 for i=1,700 do route.points[i]={mapID=1,x=.2+i*.0005,y=i%2==0 and .5 or .501} end
 A.plan={route=route,review=true}
 A.Map.Refresh(db,route,nil)
 local count=0
 for _,stroke in ipairs(A.Map.worldLines) do if stroke:IsShown() then
  count=count+1
  local found=false;for i=1,#route.points-1 do if stroke.fromPoint==route.points[i] and stroke.toPoint==route.points[i+1] then found=true;break end end
  assert(found,'Rendered line skipped a mandatory terrain bend')
 end end
 eq(count,699)
 C_Minimap=nil;GetCVar=nil;GetMinimapShape=nil
end)

test('map refresh cannot draw an unsafe live connector between follower updates',function()
 local A,db,s,route,f=setup()
 A.Terrain={Segment=function() return false end}
 A.Map.Refresh(db,route,f)
 for _,stroke in ipairs(A.Map.worldLines) do
  if stroke:IsShown() then assert(stroke.fromPoint.x~=.1,'Unvalidated live player connector was drawn') end
 end
 C_Minimap=nil;GetCVar=nil;GetMinimapShape=nil
end)
