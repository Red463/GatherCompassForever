local _,A=...
local H={};A.Heatmap=H
local cache=setmetatable({},{__mode='k'})
local edgeAlpha=math.exp(-4)
local function key(p) return string.format('%.8f,%.8f',p.x,p.y) end
function H.Samples(route)
 if cache[route] then return cache[route] end
 local w,h=route.width or 1000,route.height or 1000
 local edges,seen={},{};local total=0;local points=route.points or {}
 local function edge(a,b)
  local ka,kb=key(a),key(b);local id=ka<kb and ka..'/'..kb or kb..'/'..ka
  if seen[id] then return end;seen[id]=true
  local d=math.sqrt(((a.x-b.x)*w)^2+((a.y-b.y)*h)^2)
  edges[#edges+1]={a=a,b=b,length=d};total=total+d
 end
 for i=1,#points-1 do edge(points[i],points[i+1]) end
 if route.loop and #points>1 then edge(points[#points],points[1]) end
 local fixed=route.corridor and type(route.heatRadius)=='number' and route.heatRadius>0 and route.heatRadius<math.huge
 local budget=fixed and (A.Coverage and A.Coverage.MAX_HEAT_SAMPLES or 4096) or 512
 local spacing=fixed and (route.heatSpacing or math.min(70,route.heatRadius*.6)) or math.max(70,total/math.max(1,budget-#edges*2))
 local radius=fixed and route.heatRadius or math.max(120,spacing*1.15)
 local quantum=fixed and math.min(35,spacing*.45) or 35
 local samples={radius=radius};local occupied={}
 local function add(x,y,density)
  local id=string.format('%d:%d',math.floor(x*w/quantum+.5),math.floor(y*h/quantum+.5))
  if occupied[id] then return end;occupied[id]=true
  if #samples<budget then samples[#samples+1]={x=x,y=y,density=density or 1} end
 end
 for _,e in ipairs(edges) do
  local steps=math.max(1,math.ceil(e.length/spacing))
  for i=0,steps do local t=i/steps;add(e.a.x+(e.b.x-e.a.x)*t,e.a.y+(e.b.y-e.a.y)*t,(e.a.density or 1)*(1-t)+(e.b.density or 1)*t) end
 end
 if #edges==0 and points[1] then add(points[1].x,points[1].y,points[1].density) end
 local bins={}
 for _,p in ipairs(samples) do
  local x,y=math.floor(p.x*w/radius),math.floor(p.y*h/radius)
  bins[x]=bins[x] or {};bins[x][y]=bins[x][y] or {};local bucket=bins[x][y];bucket[#bucket+1]=p
 end
 for _,p in ipairs(samples) do
  -- Normalize by the visible HeatBlob kernel, not every nearby stamp. Counting
  -- transparent edges used to dilute the world corridor until it disappeared.
  local overlap=0
  local x,y=math.floor(p.x*w/radius),math.floor(p.y*h/radius)
  for bx=x-1,x+1 do for by=y-1,y+1 do
   for _,q in ipairs(bins[bx] and bins[bx][by] or {}) do
    local d=(((p.x-q.x)*w)^2+((p.y-q.y)*h)^2)/(radius*radius)
    if d<1 then overlap=overlap+(math.exp(-4*d)-edgeAlpha)/(1-edgeAlpha) end
   end
  end end
  p.overlap=math.max(1,overlap)
 end
 cache[route]=samples;return samples
end
function H.Hide(pool) for _,t in ipairs(pool) do t:Hide() end end
function H.Draw(pool,parent,route,project,radiusProjection,visible,opacity)
 H.Hide(pool);opacity=opacity==nil and 1 or opacity;if opacity<=0 then return end
 local samples=H.Samples(route);local rx,ry=radiusProjection(samples.radius);local used=0
 for _,p in ipairs(samples) do
  local x,y=project(p)
  if not visible or visible(x,y,rx,ry) then
   used=used+1;local t=pool[used]
   if not t then t=parent:CreateTexture(nil,'ARTWORK');pool[used]=t end
   t:SetTexture('Interface\\AddOns\\Gatherly\\Media\\HeatBlob')
   local density=math.min(1,math.log(1+p.density)/math.log(20))
   t:SetVertexColor(route.corridor and .82 or .60,route.corridor and .035-.02*density or .18-.12*density,.015,1-math.exp(-(1.8+.2*density)/(p.overlap or 1)))
   t:SetAlpha(math.min(1,opacity))
   t:SetSize(rx*2,ry*2);t:ClearAllPoints();t:SetPoint('CENTER',parent,'TOPLEFT',x,y);t:Show()
  end
 end
end
