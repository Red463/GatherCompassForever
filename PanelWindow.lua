local _,A=...
local P={};A.PanelWindow=P
P.Presets={{id='small',label='Small',width=960,height=680},{id='standard',label='Standard',width=1100,height=780},{id='large',label='Large',width=1240,height=880}}
local function number(v,default,lo,hi)
 if not A.Store.Number(v) then return default end
 return math.max(lo,math.min(hi,v))
end
local function find(id)
 for i,p in ipairs(P.Presets) do if p.id==id then return p,i end end
end
local function preference(settings)
 local p=type(settings.panel)=='table' and settings.panel or {};settings.panel=p
 if not find(p.preset) then
  p.preset='standard'
  if A.Store.Number(p.width) and A.Store.Number(p.height) then
   local best
   for _,preset in ipairs(P.Presets) do local d=(number(p.width,1100,0,100000)-preset.width)^2+(number(p.height,780,0,100000)-preset.height)^2
    if not best or d<best then best=d;p.preset=preset.id end
   end
  end
 end
 p.width=nil;p.height=nil
 p.x=number(p.x,.5,0,1);p.y=number(p.y,.5,0,1);return p
end
function P.Resolve(settings,vw,vh,compact)
 local p=preference(settings);vw=number(vw,1100,25,100000);vh=number(vh,780,25,100000)
 local requested,index=find(p.preset);local effective=P.Presets[1]
 for i=1,index do local candidate=P.Presets[i]
  if candidate.width<=vw-24 and candidate.height<=vh-24 then effective=candidate end
 end
 local w,h=effective.width,effective.height;if compact then w,h=730,98 end
 local scale=math.min(1,(vw-24)/w,(vh-24)/h)
 local sw,sh=w*scale,h*scale
 local left=math.max(12,math.min(vw-12-sw,p.x*vw-sw/2))
 local top=math.max(12+sh,math.min(vh-12,p.y*vh+sh/2))
 return {width=w,height=h,scale=scale,left=left,top=top,screenWidth=vw,screenHeight=vh,preset=requested.id,effectivePreset=effective.id,label=effective.label}
end
function P.New(U)
 local self={}
 function self:Cancel() if self.moving then self:StopMoving() end end
 function self:Apply()
  local g=P.Resolve(A.db.settings,UIParent:GetWidth(),UIParent:GetHeight(),U.compact)
  local old=self.geometry
  if old and (old.width~=g.width or old.height~=g.height or old.scale~=g.scale) then
   A.Skin.CloseDropdown();if U.routeSketch then U.routeSketch.picker:Close() end
  end
  self.geometry=g;U.frame:SetSize(g.width,g.height);U.frame:SetScale(g.scale)
  if not self.moving then U.frame:ClearAllPoints();U.frame:SetPoint('TOPLEFT',UIParent,'BOTTOMLEFT',g.left/g.scale,g.top/g.scale) end
  return g.width,g.height
 end
 function self:StartMoving() self:Cancel();self.moving=true;U.frame:StartMoving() end
 function self:StopMoving()
  if not self.moving then return end
  U.frame:StopMovingOrSizing();self:SavePosition();self.moving=nil
 end
 function self:SavePosition()
  local x,y=U.frame:GetCenter();local scale=U.frame:GetEffectiveScale()/UIParent:GetEffectiveScale()
  if A.Store.Number(x) and A.Store.Number(y) then
   local p=preference(A.db.settings);p.x=number(x*scale/UIParent:GetWidth(),.5,0,1);p.y=number(y*scale/UIParent:GetHeight(),.5,0,1)
   self.geometry=P.Resolve(A.db.settings,UIParent:GetWidth(),UIParent:GetHeight(),U.compact)
  end
 end
 function self:SetPreset(id)
  if not find(id) then return false end
  self:Cancel();A.Skin.CloseDropdown();preference(A.db.settings).preset=id;U.Refresh();return true
 end
 function self:Reset() return self:SetPreset('standard') end
 U.frame:HookScript('OnHide',function() self:Cancel() end)
 return self
end
