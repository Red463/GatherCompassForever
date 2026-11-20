local _, A = ...
local T={}; A.Terrain=T
local floor,abs,sqrt,min,max=math.floor,math.abs,math.sqrt,math.min,math.max
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local decode={};for i=1,#alphabet do decode[alphabet:byte(i)]=i-1 end
local powers={32,16,8,4,2,1}
local function number(n)
 return not (issecretvalue and issecretvalue(n)) and type(n)=='number' and n==n and n>-math.huge and n<math.huge
end
local function position(p)
 return type(p)=='table' and number(p.mapID) and p.mapID>0 and p.mapID%1==0 and number(p.x) and number(p.y) and p.x>=0 and p.x<=1 and p.y>=0 and p.y<=1
end
local function point(p) return {mapID=p.mapID,x=p.x,y=p.y} end
local function copy(v,seen)
 if type(v)~='table' then return v end
 seen=seen or {};if seen[v] then return seen[v] end
 local r={};seen[v]=r;for k,value in pairs(v) do r[k]=copy(value,seen) end;return r
end
function T.Zone(mapID)
 if not number(mapID) or mapID<1 or mapID%1~=0 then return nil,'unavailable' end
 local data=A.TerrainData
 local z=type(data)=='table' and data.version==1 and type(data.zones)=='table' and data.zones[mapID]
 if type(z)~='table' or (z.status~='complete' and z.status~='partial') or not number(z.w) or not number(z.h) or z.w<1 or z.h<1 or z.w%1~=0 or z.h%1~=0 or z.w>8192 or z.h>8192 or not number(z.widthYards) or not number(z.heightYards) or z.widthYards<=0 or z.heightYards<=0 or type(z.rows)~='table' then return nil,'unavailable' end
 return z
end
local function cell(z,x,y)
 if x<0 or y<0 or x>=z.w or y>=z.h then return false end
 local row=z.rows[y+1];if type(row)~='string' then return false end
 local bits=decode[row:byte(floor(x/6)+1)]
 return bits~=nil and floor(bits/powers[x%6+1])%2==1
end
local function coordinates(z,p) return min(z.w-1,floor(p.x*z.w)),min(z.h-1,floor(p.y*z.h)) end
function T.Allowed(p)
 if not position(p) then return false end
 local z=T.Zone(p.mapID);if not z then return false end
 local x,y=coordinates(z,p);return cell(z,x,y)
end
local function touches(z,x,y)
 local ix,iy=min(z.w-1,floor(x)),min(z.h-1,floor(y))
 if not cell(z,ix,iy) then return false end
 local left=x>0 and x<z.w and abs(x-floor(x+.5))<1e-10
 local up=y>0 and y<z.h and abs(y-floor(y+.5))<1e-10
 if left and not cell(z,ix-1,iy) then return false end
 if up and not cell(z,ix,iy-1) then return false end
 if left and up and not cell(z,ix-1,iy-1) then return false end
 return true
end
-- Grid traversal visits every touched cell, including both sides of a corner
-- or grid edge. A diagonal may never slip between two prohibited cells.
local function segment(z,a,b)
 local ax,ay,bx,by=a.x*z.w,a.y*z.h,b.x*z.w,b.y*z.h
 if not touches(z,ax,ay) or not touches(z,bx,by) then return false end
 local x,y=coordinates(z,a);local ex,ey=coordinates(z,b)
 local dx,dy=bx-ax,by-ay
 if dx==0 and dy==0 then return true end
 local sx=dx>0 and 1 or dx<0 and -1 or 0;local sy=dy>0 and 1 or dy<0 and -1 or 0
 local tx=dx==0 and math.huge or ((sx>0 and x+1 or x)-ax)/dx
 local ty=dy==0 and math.huge or ((sy>0 and y+1 or y)-ay)/dy
 local dtx=dx==0 and math.huge or abs(1/dx);local dty=dy==0 and math.huge or abs(1/dy)
 local vertical=dx==0 and ax>0 and ax<z.w and abs(ax-floor(ax+.5))<1e-10
 local horizontal=dy==0 and ay>0 and ay<z.h and abs(ay-floor(ay+.5))<1e-10
 local work=0
 while true do
  if not cell(z,x,y) or (vertical and not cell(z,x-1,y)) or (horizontal and not cell(z,x,y-1)) then return false end
  if x==ex and y==ey then return true end
  -- The endpoint's touching cells were checked above. Do not step beyond it
  -- when a negative-going axis lands exactly on a grid boundary.
  if min(tx,ty)>=1-1e-12 then return true end
  work=work+1;if work%256==0 and T.Checkpoint then T.Checkpoint() end
  if abs(tx-ty)<1e-10 then
   if not cell(z,x+sx,y) or not cell(z,x,y+sy) then return false end
   x=x+sx;y=y+sy;tx=tx+dtx;ty=ty+dty
  elseif tx<ty then x=x+sx;tx=tx+dtx
  else y=y+sy;ty=ty+dty end
 end
end
function T.Segment(a,b)
 if not position(a) or not position(b) or a.mapID~=b.mapID then return false end
 local z=T.Zone(a.mapID);return z and segment(z,a,b) or false
end
local function yards(z,a,b) return sqrt(((a.x-b.x)*z.widthYards)^2+((a.y-b.y)*z.heightYards)^2) end
function T.Approach(p,maxYards)
 if not position(p) then return nil,'invalid point' end
 local z,reason=T.Zone(p.mapID);if not z then return nil,reason end
 if segment(z,p,p) then return point(p) end
 maxYards=maxYards==nil and 30 or maxYards
 if not number(maxYards) or maxYards<0 then return nil,'invalid distance' end
 local cx,cy=coordinates(z,p);local rx=min(z.w,math.ceil(maxYards*z.w/z.widthYards)+1);local ry=min(z.h,math.ceil(maxYards*z.h/z.heightYards)+1)
 local best,bestDistance;local work=0
 for y=max(0,cy-ry),min(z.h-1,cy+ry) do
  for x=max(0,cx-rx),min(z.w-1,cx+rx) do
   work=work+1;if work>16384 then return nil,'budget' end
   if cell(z,x,y) then
    local candidate={mapID=p.mapID,x=(x+.5)/z.w,y=(y+.5)/z.h};local d=yards(z,p,candidate)
    if d<=maxYards+1e-8 and (not bestDistance or d<bestDistance) then best=candidate;bestDistance=d end
   end
  end
 end
 if best then return best end
 return nil,'no approach'
end
local cachedZone,cache,order,cachePoints=nil,{},{},0
local function cacheKey(a,b)
 local first=string.format('%.17g,%.17g',a.x,a.y);local last=string.format('%.17g,%.17g',b.x,b.y)
 if first>last then return a.mapID..':'..last..':'..first,true end
 return a.mapID..':'..first..':'..last,false
end
local function pathCopy(points,reverse)
 local result={};for i=1,#points do result[i]=point(points[reverse and #points-i+1 or i]) end;return result
end
local function remember(key,reverse,points,length)
 if cache[key] then return end
 while #order>=128 or cachePoints+#points>8192 do
  local oldest=table.remove(order,1);cachePoints=cachePoints-#cache[oldest].points;cache[oldest]=nil
 end
 order[#order+1]=key;cache[key]={points=pathCopy(points,reverse),length=length}
 cachePoints=cachePoints+#points
end
-- The heap admits replacement entries; stale entries are discarded on pop.
local function push(heap,id,f,g)
 local i=#heap+1;local value={id=id,f=f,g=g}
 while i>1 do local parent=floor(i/2);if heap[parent].f<=f then break end;heap[i]=heap[parent];i=parent end
 heap[i]=value
end
local function pop(heap)
 local first,last=heap[1],table.remove(heap);if #heap==0 then return first end
 local i=1
 while i*2<=#heap do
  local child=i*2;if child<#heap and heap[child+1].f<heap[child].f then child=child+1 end
  if heap[child].f>=last.f then break end
  heap[i]=heap[child];i=child
 end
 heap[i]=last;return first
end
local neighbors={{-1,0},{1,0},{0,-1},{0,1},{-1,-1},{-1,1},{1,-1},{1,1}}
function T.Path(a,b,options)
 if not position(a) or not position(b) then return nil,'invalid point' end
 if a.mapID~=b.mapID then return nil,'map mismatch' end
 local z,reason=T.Zone(a.mapID);if not z then return nil,reason end
 if not segment(z,a,a) or not segment(z,b,b) then return nil,'blocked endpoint' end
 if segment(z,a,b) then return {point(a),point(b)},yards(z,a,b) end
 if cachedZone~=z then cachedZone=z;cache={};order={};cachePoints=0 end
 local key,reverse=cacheKey(a,b);local hit=cache[key]
 if hit then return pathCopy(hit.points,reverse),hit.length end
 options=type(options)=='table' and options or {}
 local budget=options.maxExpansions or options.budget or 16384
 if not number(budget) or budget<0 then return nil,'invalid budget' end
 budget=min(262144,floor(budget))
 local yield=type(options.yield)=='function' and options.yield
 local sx,sy=coordinates(z,a);local ex,ey=coordinates(z,b);local start=sy*z.w+sx;local goal=ey*z.w+ex
 local wx,wy=z.widthYards/z.w,z.heightYards/z.h
 local function heuristic(x,y) return sqrt(((ex-x)*wx)^2+((ey-y)*wy)^2) end
 local heap,scores,previous,closed={},{[start]=0},{},{};push(heap,start,heuristic(sx,sy),0)
 local work=0;local found=false
 while #heap>0 do
  local entry=pop(heap);local id=entry.id
  if not closed[id] and entry.g==scores[id] then
   if id==goal then found=true;break end
   if work>=budget then return nil,'budget' end
   work=work+1;closed[id]=true
   if work%256==0 then
    -- A planning job installs a fresh frame clock on every resume.
    local checkpoint=yield or T.Checkpoint
    if type(checkpoint)=='function' then checkpoint(work) end
   end
   local x,y=id%z.w,floor(id/z.w)
   for _,offset in ipairs(neighbors) do
    local dx,dy=offset[1],offset[2];local nx,ny=x+dx,y+dy;local nid=ny*z.w+nx
    if not closed[nid] and cell(z,nx,ny) and (dx==0 or dy==0 or (cell(z,x+dx,y) and cell(z,x,y+dy))) then
     local g=entry.g+sqrt((dx*wx)^2+(dy*wy)^2)
     if not scores[nid] or g<scores[nid] then scores[nid]=g;previous[nid]=id;push(heap,nid,g+heuristic(nx,ny),g) end
    end
   end
  end
 end
 if not found then return nil,'unreachable' end
 local backwards={point(b)};local id=goal
 while true do
  backwards[#backwards+1]={mapID=a.mapID,x=(id%z.w+.5)/z.w,y=(floor(id/z.w)+.5)/z.h}
  if #backwards%256==0 and T.Checkpoint then T.Checkpoint() end
  if id==start then break end;id=previous[id]
 end
 backwards[#backwards+1]=point(a)
 local raw=pathCopy(backwards,true);local result={raw[1]};local at=1;local length=0;local shortcuts=0
 -- Bounded lookahead smooths grid stairs without quadratic path scans. Every
 -- accepted shortcut uses the same supercover predicate as route validation.
 while at<#raw do
  local nextIndex=at+1
  for i=min(#raw,at+64),at+2,-1 do
   shortcuts=shortcuts+1;if shortcuts%16==0 and T.Checkpoint then T.Checkpoint() end
   if segment(z,raw[at],raw[i]) then nextIndex=i;break end
  end
  if not segment(z,raw[at],raw[nextIndex]) then return nil,'unreachable' end
  length=length+yards(z,raw[at],raw[nextIndex]);result[#result+1]=raw[nextIndex];at=nextIndex
 end
 -- Bound retained geometry as well as cache entry count.
 if #result<=1024 then remember(key,reverse,result,length) end
 return result,length
end
function T.Distance(a,b,options)
 local path,length=T.Path(a,b,options);if not path then return nil,length end;return length
end
local function routeShape(route)
 if type(route)~='table' or type(route.points)~='table' or #route.points==0 then return false end
 local n=#route.points
 for k in pairs(route.points) do if type(k)~='number' or k%1~=0 or k<1 or k>n then return false end end
 for i=1,n do if not position(route.points[i]) then return false end end
 return true
end
function T.Validate(route)
 if not routeShape(route) then return false,'invalid route' end
 local points=route.points
 for i,p in ipairs(points) do
  if not T.Segment(p,p) then return false,'blocked endpoint' end
  if i>1 and not T.Segment(points[i-1],p) then return false,'blocked segment' end
  if i%64==0 and T.Checkpoint then T.Checkpoint() end
 end
 if route.loop and #points>1 and not T.Segment(points[#points],points[1]) then return false,'blocked closure' end
 return true
end
function T.Route(route,options)
 if not routeShape(route) then return nil,'invalid route' end
 local original=route.points;local expanded={}
 for i,p in ipairs(original) do
  if not position(p) then return nil,'invalid point' end
  if not T.Segment(p,p) then return nil,T.Zone(p.mapID) and 'blocked endpoint' or 'unavailable' end
  expanded[#expanded+1]=copy(p)
  local target=original[i+1] or (route.loop and #original>1 and original[1])
  if target then
   local path,reason=T.Path(p,target,options);if not path then return nil,reason end
   for j=2,#path-1 do
    local bend=point(path[j]);bend.kind='travel';bend.mandatory=true;bend.navigation=true;expanded[#expanded+1]=bend
   end
  end
  if i%64==0 and T.Checkpoint then T.Checkpoint() end
 end
 local result={};for k,v in pairs(route) do if k~='points' then result[k]=copy(v) end end
 result.points=expanded;result.terrainVersion=1
 local valid,reason=T.Validate(result);if not valid then return nil,reason end
 return result
end
