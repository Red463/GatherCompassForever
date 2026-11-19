local _, A = ...
A.RouteSketch={}
function A.RouteSketch.New(parent)
 local s={frame=A.Skin.Panel(parent,{.065,.13,.085,1},{.20,.29,.20,1}),lines={},marks={}}
 local caption=A.Skin.Label(s.frame,'ROUTE SKETCH',9,A.Skin.muted); caption:SetPoint('TOPLEFT',s.frame,'TOPLEFT',12,-12); caption:SetSize(200,12)
 function s:Draw(route,selectedIndex)
  local points=route and route.points or {}; local w,h=self.frame:GetWidth(),self.frame:GetHeight()
  local geometry={}; for _,p in ipairs(points) do geometry[#geometry+1]=string.format('%.17g,%.17g',p.x,p.y) end
  local key=tostring(route and route.mapID)..':'..table.concat(geometry,';')..':'..tostring(selectedIndex)..':'..w..':'..h..':'..tostring(route and route.loop)
  if self.key==key then return end; self.key=key
  for _,l in ipairs(self.lines) do l:Hide() end; for _,t in ipairs(self.marks) do t:Hide() end
  if #points==0 then return end
  local minX,minY,maxX,maxY=1,1,0,0
  for _,p in ipairs(points) do minX=math.min(minX,p.x); minY=math.min(minY,p.y); maxX=math.max(maxX,p.x); maxY=math.max(maxY,p.y) end
  local zw,zh
  if A.Client and A.Client.Size then zw,zh=A.Client.Size(route.mapID) end
  zw,zh=zw or 1,zh or 1
  local spanX,spanY=math.max((maxX-minX)*zw,1e-6),math.max((maxY-minY)*zh,1e-6)
  local scale=math.min(math.max(1,w-48)/spanX,math.max(1,h-64)/spanY)
  local function project(p) return w/2+(p.x-(minX+maxX)/2)*zw*scale,-(h/2+12+(p.y-(minY+maxY)/2)*zh*scale) end
  local used=0; local stride=math.max(1,math.ceil((#points-1)/255))
  local function line(a,b)
   used=used+1; local l=self.lines[used]
   if not l then l=self.frame:CreateLine(nil,'ARTWORK'); self.lines[used]=l end
   local x1,y1=project(a); local x2,y2=project(b)
   l:SetColorTexture(.77,.70,.46,1); l:SetThickness(2); l:SetStartPoint('TOPLEFT',self.frame,x1,y1); l:SetEndPoint('TOPLEFT',self.frame,x2,y2); l:Show()
  end
  for i=1,#points-1,stride do line(points[i],points[math.min(i+stride,#points)]) end
  if route.loop and #points>1 then line(points[#points],points[1]) end
  local marked=0
  local function mark(i,selected)
   marked=marked+1; local t=self.marks[marked]
   if not t then t=self.frame:CreateTexture(nil,'OVERLAY'); self.marks[marked]=t end
   local x,y=project(points[i]); t:SetColorTexture(selected and 1 or .58,selected and .86 or .70,selected and .55 or .44,1); t:SetSize(selected and 8 or 4,selected and 8 or 4); t:ClearAllPoints(); t:SetPoint('CENTER',self.frame,'TOPLEFT',x,y); t:Show()
  end
  for i=1,#points,math.max(1,math.ceil(#points/70)) do mark(i,false) end
  if selectedIndex and points[selectedIndex] then mark(selectedIndex,true) end
 end
 return s
end
