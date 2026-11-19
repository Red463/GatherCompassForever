local _,A=...
local P={};A.PanelWindow=P
local function number(v,default,lo,hi)
 if not A.Store.Number(v) then return default end
 return math.max(lo,math.min(hi,v))
end
local function preference(settings)
 local p=type(settings.panel)=='table' and settings.panel or {};settings.panel=p
 p.width=math.floor(number(p.width,960,860,100000)+.5);p.height=math.floor(number(p.height,624,600,100000)+.5)
 p.x=number(p.x,.5,0,1);p.y=number(p.y,.5,0,1);return p
end
function P.Resolve(settings,vw,vh,compact)
 local p=preference(settings);vw=number(vw,960,25,100000);vh=number(vh,624,25,100000)
 local w=compact and 730 or math.max(860,math.min(p.width,vw-24))
 local h=compact and 98 or math.max(600,math.min(p.height,vh-24))
 local scale=math.min(1,(vw-24)/w,(vh-24)/h)
 local sw,sh=w*scale,h*scale
 local left=math.max(12,math.min(vw-12-sw,p.x*vw-sw/2))
 local top=math.max(12+sh,math.min(vh-12,p.y*vh+sh/2))
 return {width=w,height=h,scale=scale,left=left,top=top,screenWidth=vw,screenHeight=vh}
end
function P.New(U)
 local self={driver=CreateFrame('Frame',nil,U.frame)}
 function self:Cancel() self.drag=nil;self.driver:SetScript('OnUpdate',nil) end
 function self:Apply()
  local g=P.Resolve(A.db.settings,UIParent:GetWidth(),UIParent:GetHeight(),U.compact)
  local old=self.geometry
  if old and (old.width~=g.width or old.height~=g.height or old.scale~=g.scale) then
   A.Skin.CloseDropdown();if U.routeSketch then U.routeSketch.picker:Close() end
  end
  self.geometry=g
  U.frame:SetSize(g.width,g.height);U.frame:SetScale(g.scale)
  if not self.moving then U.frame:ClearAllPoints();U.frame:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',g.left/g.scale,g.top/g.scale) end
  if U.compact then self.grip:Hide() else self.grip:Show() end
  return g.width,g.height
 end
 function self:StartMoving()
  self:Cancel();self.moving=true;U.frame:StartMoving()
 end
 function self:StopMoving()
  U.frame:StopMovingOrSizing();self:SavePosition();self.moving=nil
 end
 function self:SavePosition()
  local x,y=U.frame:GetCenter();local scale=U.frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
  if A.Store.Number(x) and A.Store.Number(y) then
   local p=preference(A.db.settings);p.x=number(x*scale/UIParent:GetWidth(),.5,0,1);p.y=number(y*scale/UIParent:GetHeight(),.5,0,1)
   self.geometry=P.Resolve(A.db.settings,UIParent:GetWidth(),UIParent:GetHeight(),U.compact)
  end
 end
 function self:Resize(w,h,axes)
  if not A.Store.Number(w) or not A.Store.Number(h) then return end
  local p=preference(A.db.settings)
  if not axes or axes.width then p.width=math.floor(math.max(860,w)+.5) end
  if not axes or axes.height then p.height=math.floor(math.max(600,h)+.5) end
  if self.drag then
   local g=P.Resolve(A.db.settings,UIParent:GetWidth(),UIParent:GetHeight(),false)
   p.x=(self.drag.left+g.width*g.scale/2)/g.screenWidth;p.y=(self.drag.top-g.height*g.scale/2)/g.screenHeight
  end
  U.Refresh()
 end
 function self:Reset()
  self:Cancel();local p=preference(A.db.settings);p.width=960;p.height=624;U.Refresh()
 end
 local grip=CreateFrame('Button',nil,U.frame);self.grip=grip;grip:SetSize(24,24);grip:SetPoint('BOTTOMRIGHT',U.frame,'BOTTOMRIGHT',-3,3)
 grip:SetFrameLevel(U.frame:GetFrameLevel()+50);grip:EnableMouse(true)
 grip:SetNormalTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up')
 grip:SetHighlightTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight')
 grip:SetPushedTexture('Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down')
 A.Skin.Hint(grip,'Resize panel','Drag to resize the window. Text and controls keep their normal size. Reset panel size in Preferences.')
 local function update(_,elapsed)
  if not self.drag then return end
  self.elapsed=(self.elapsed or 0)+elapsed;if self.elapsed<.05 then return end;self.elapsed=0
  local x,y=GetCursorPosition();if not A.Store.Number(x) or not A.Store.Number(y) then self:Cancel();return end
  local d=self.drag
  local maxW=math.max(860,math.floor((UIParent:GetWidth()-12-d.left)/d.windowScale))
  local maxH=math.max(600,math.floor((d.top-12)/d.windowScale))
  local w=math.max(860,math.min(maxW,math.floor(d.width+(x-d.x)/d.scale+.5)))
  local h=math.max(600,math.min(maxH,math.floor(d.height-(y-d.y)/d.scale+.5)))
  if w~=d.width then d.changedWidth=true end;if h~=d.height then d.changedHeight=true end
  if (d.changedWidth and w~=self.geometry.width) or (d.changedHeight and h~=self.geometry.height) then
   self:Resize(w,h,{width=d.changedWidth,height=d.changedHeight})
  end
  if type(IsMouseButtonDown)=='function' and not IsMouseButtonDown('LeftButton') then self:Cancel() end
 end
 grip:SetScript('OnMouseDown',function(_,button)
  if button~='LeftButton' or U.compact or type(GetCursorPosition)~='function' then return end
  local x,y=GetCursorPosition();if not A.Store.Number(x) or not A.Store.Number(y) then return end
  U.frame:StopMovingOrSizing();A.Skin.CloseDropdown()
  if U.routeSketch then U.routeSketch.picker:Close() end
  local g=self.geometry;self.drag={x=x,y=y,width=g.width,height=g.height,left=g.left,top=g.top,windowScale=g.scale,scale=U.frame:GetEffectiveScale()};self.elapsed=0
  self.driver:SetScript('OnUpdate',update)
 end)
 grip:SetScript('OnMouseUp',function() if self.drag then update(nil,.05);self:Cancel() end end)
 U.frame:HookScript('OnHide',function() if self.moving then self:StopMoving() end;self:Cancel() end)
 return self
end
