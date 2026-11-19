local _,A=...
A.RouteSketch={}
local function hide(pool) for _,f in ipairs(pool) do f:Hide() end end
local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
-- Clip strokes as well as pins, so panning never leaves click targets outside the map.
local function clip(x1,y1,x2,y2,w,h)
 local lo,hi=0,1;local dx,dy=x2-x1,y2-y1
 for _,v in ipairs({{-dx,x1},{dx,w-x1},{-dy,y1},{dy,h-y1}}) do
  if v[1]==0 then if v[2]<0 then return end
  else local t=v[2]/v[1];if v[1]<0 then lo=math.max(lo,t) else hi=math.min(hi,t) end;if lo>hi then return end end
 end
 return x1+dx*lo,y1+dy*lo,x1+dx*hi,y1+dy*hi
end
function A.RouteSketch.New(parent)
 local S=A.Skin;local s={frame=S.Panel(parent),lines={},marks={},pins={},heat={},zoom=1,cx=.5,cy=.5}
 s.viewport=CreateFrame('Frame',nil,s.frame);s.viewport:SetPoint('TOPLEFT',s.frame,'TOPLEFT',3,-3);s.viewport:SetPoint('BOTTOMRIGHT',s.frame,'BOTTOMRIGHT',-3,3);s.viewport:SetClipsChildren(true)
 s.canvas=CreateFrame('Frame',nil,s.viewport);s.canvas:SetAllPoints();s.canvas:EnableMouse(false)
 s.art=A.MapArt.New(s.canvas)
 s.picker=A.GroupPicker.New(s.frame,function(key) if s.last and s.last[3].onSelect then s.last[3].onSelect(key) end end)
 s.fallback=S.Label(s.canvas,'Map artwork unavailable - schematic view',11,S.muted);s.fallback:SetPoint('BOTTOMLEFT',s.canvas,'BOTTOMLEFT',8,6);s.fallback:SetSize(500,20)
 function s:Bounds()
  local w,h=self.frame:GetWidth()-6,self.frame:GetHeight()-6
  local ratio=(w/h)/(self.art.aspect or self.aspect or 1.5)
  local sx,sy=math.max(1,ratio)/self.zoom,math.max(1,1/ratio)/self.zoom
  return {left=self.cx-sx/2,right=self.cx+sx/2,top=self.cy-sy/2,bottom=self.cy+sy/2},w,h
 end
 function s:Zoom(delta)
  self.zoom=clamp(self.zoom*1.25^delta,1,8);if self.last then self:Draw(unpack(self.last,1,3)) end
 end
 function s:Pan(dx,dy)
  if dx==0 and dy==0 then return end
  local b,w,h=self:Bounds();self.cx=clamp(self.cx-dx/w*(b.right-b.left),0,1);self.cy=clamp(self.cy+dy/h*(b.bottom-b.top),0,1)
  if self.last then self:Draw(unpack(self.last,1,3)) end
 end
 s.viewport:EnableMouse(true);s.viewport:EnableMouseWheel(true);s.viewport:RegisterForDrag('RightButton')
 s.viewport:SetScript('OnMouseWheel',function(_,delta) s:Zoom(delta) end)
 local function cancel() s.picker:Close();s.dragging=nil;s.viewport:SetScript('OnUpdate',nil) end
 s.viewport:SetScript('OnDragStart',function()
  if not GetCursorPosition then return end
  local x,y=GetCursorPosition();s.dragging={x=x,y=y}
  s.viewport:SetScript('OnUpdate',function()
   local nx,ny=GetCursorPosition();local d=s.dragging;if not d then return end
   local scale=s.viewport:GetEffectiveScale();s:Pan((nx-d.x)/scale,(ny-d.y)/scale);d.x=nx;d.y=ny
  end)
 end)
 s.viewport:SetScript('OnDragStop',cancel);s.viewport:SetScript('OnHide',cancel);s.frame:SetScript('OnHide',cancel)
 function s:Draw(route,selectedIndex,options)
  options=options or {};self.last={route,selectedIndex,options};self.last.n=3
  local mapID=route and route.mapID or options.mapID
  local b,w,h=self:Bounds();self.art:Draw(mapID,b,w,h)
  local identity=options.plan or route or mapID
  if self.identity~=identity then
   self.identity=identity;self.zoom=1;self.cx=.5;self.cy=.5
   local zw,zh;if A.Client and A.Client.Size and mapID then zw,zh=A.Client.Size(mapID) end;self.aspect=zw and zh and zw/zh or 1.5
   if route and #route.points>0 then
    local lx,ly,rx,ry=1,1,0,0
    for _,p in ipairs(route.points) do lx=math.min(lx,p.x);ly=math.min(ly,p.y);rx=math.max(rx,p.x);ry=math.max(ry,p.y) end
    self.cx=(lx+rx)/2;self.cy=(ly+ry)/2
    local ratio=(w/h)/(self.art.aspect or self.aspect)
    self.zoom=clamp(math.min(math.max(1,ratio)/math.max(.1,rx-lx+.12),math.max(1,1/ratio)/math.max(.1,ry-ly+.12)),1,8)
   end
  end
  b,w,h=self:Bounds();self.bounds=b;self.art:Draw(mapID,b,w,h)
  if self.art.available then self.fallback:Hide() else self.fallback:Show() end
  hide(self.lines);hide(self.marks);hide(self.pins);A.Heatmap.Hide(self.heat)
  local function project(p) return A.MapArt.Project(p,b,w,h) end;self.Project=project
  local points=route and route.points or {};local geometry={}
  for _,p in ipairs(points) do geometry[#geometry+1]=string.format('%.17g,%.17g',p.x,p.y) end
  self.key=table.concat(geometry,';')..tostring(selectedIndex)..tostring(route and route.loop)..self.zoom..self.cx..self.cy
  if options.style=='heatmap' and route then
   local zw,zh=route.width or 1000,route.height or 1000
   A.Heatmap.Draw(self.heat,self.canvas,route,project,function(radius) return radius/zw/(b.right-b.left)*w,radius/zh/(b.bottom-b.top)*h end,function(x,y,rx,ry) return x+rx>=0 and x-rx<=w and y+ry>=-h and y-ry<=0 end)
  else
   local used=0
   local function line(a,c)
    local x1,y1=project(a);local x2,y2=project(c);x1,y1,x2,y2=clip(x1,-y1,x2,-y2,w,h);if not x1 then return end
    used=used+1;local l=self.lines[used];if not l then l=self.canvas:CreateLine(nil,'ARTWORK');self.lines[used]=l end
    l:SetColorTexture(1,.78,.28,.9);l:SetThickness(1.5);l:SetStartPoint('TOPLEFT',self.canvas,x1,-y1);l:SetEndPoint('TOPLEFT',self.canvas,x2,-y2);l:Show()
   end
   local stride=math.max(1,math.ceil((#points-1)/255))
   for i=1,#points-1,stride do line(points[i],points[math.min(i+stride,#points)]) end
   if route and route.loop and #points>1 then line(points[#points],points[1]) end
  end
  local nodes=options.nodes or points;local plan=options.plan
  if self.picker.plan~=plan or self.picker.revision~=(plan and plan.revision) then self.picker:Close() end
  local grouping=not A.db or A.Resources.Settings(A.db.settings).groupWorld
  local cacheKey=tostring(nodes)..':'..tostring(plan and plan.revision)..':'..tostring(options.selected)..':'..self.zoom..':'..w..':'..h..':'..tostring(self.art.aspect or self.aspect)..':'..tostring(grouping)
  if self.groupsKey~=cacheKey then
   local candidates={};for _,n in ipairs(nodes) do if not plan or not plan.excluded[n.key or A.FarmingSession.Key(n)] then candidates[#candidates+1]=n end end
   self.groups=A.MarkerGroups.Build(candidates,project,grouping and 20 or .000001,{focus=options.selected,disabled=not grouping});self.groupsKey=cacheKey
  end
  local used=0
  for _,g in ipairs(self.groups) do
   if used>=400 then break end
   local n=g.anchor;local key=A.FarmingSession and A.FarmingSession.Key(n) or tostring(n);local x,y=project(n)
   if x>=10 and x<=w-10 and y<= -10 and y>= -h+10 then
    used=used+1;local f=self.pins[used]
    if not f then
     f=CreateFrame('Button',nil,self.canvas);f:SetSize(18,18);f:RegisterForClicks('LeftButtonUp');self.pins[used]=f
     f.icon=f:CreateTexture(nil,'ARTWORK');f.icon:SetAllPoints()
     f.halo=f:CreateTexture(nil,'OVERLAY');f.halo:SetTexture(S.media..'NodeRing');f.halo:SetSize(28,28);f.halo:SetPoint('CENTER');f.halo:SetVertexColor(1,.82,.35,1)
     f.count=S.Label(f,'',11,S.gold);f.count:SetPoint('CENTER',f,'CENTER',10,8);f.count:SetSize(35,20)
     f:SetScript('OnClick',function(button)
      if #button.group.members>1 then self.picker:Open(button.group.members,button,button.plan)
      elseif button.select then button.select(button.nodeKey) end
     end)
     A.SkillTooltip.Bind(f,function() return f.group and #f.group.members>1 and (#f.group.members..' known locations') or 'Known location' end,function() return f.group and A.SkillTooltip.Entries(f.group.members) or {} end,'Click to choose a location. Removal affects this route only.')
    end
    f.group=g;f.plan=plan;f.nodeKey=key;f.node=n;f.select=options.onSelect;f:ClearAllPoints();f:SetPoint('CENTER',self.canvas,'TOPLEFT',x,y)
    f.icon:SetTexture(g.mixed and S.media..'Icon' or A.Resources.Icon(n))
    local included=not plan or not route;local selected=false
    for _,member in ipairs(g.members) do
     if route and route.includedKeys and route.includedKeys[member.key] then included=true end
     if member.key==options.selected then selected=true end
    end
    f:SetAlpha((included or selected) and 1 or .4)
    if #g.members>1 then f.count:SetText(tostring(#g.members));f.count:Show() else f.count:Hide() end
    if selected then f.halo:Show() else f.halo:Hide() end;f:Show()
   end
  end

 end
 return s
end
