local _,A=...
local P={};A.MinimapPins=P
-- The bundled pin library predates Forever's ignored-rotation API. Use an
-- addon-owned projection in that mode, without changing the shared library.
function P.New(project)
 local self={frames={},driver=CreateFrame('Frame'),elapsed=0}
 function self:Add(frame,point)
  self.frames[frame]=point;frame.directMini=true;frame:SetParent(Minimap);frame:SetFrameLevel(Minimap:GetFrameLevel()+5)
 end
 function self:Remove(frame)
  self.frames[frame]=nil;frame.directMini=nil;frame:SetParent(UIParent);frame:Hide()
 end
 function self:Refresh()
  if not next(self.frames) then return end
  local player=A.Client.Position();local w,h;if player then w,h=A.Client.Size(player.mapID) end
  local radius,facing=A.Client.MinimapRadius(),A.Client.MinimapFacing();local shape=A.Client.MinimapShape()
  local valid=Minimap and Minimap:IsShown() and A.Client.MinimapRotationIgnored()==true and A.Store.Position(player) and A.Store.Number(w) and A.Store.Number(h) and radius and facing~=nil
  local scale=Minimap and Minimap.GetScale and Minimap:GetScale() or 1
  if not A.Store.Number(scale) or scale<=0 then scale=1 end
  for frame,point in pairs(self.frames) do
   local x,y
   if valid and point.mapID==player.mapID then
    x,y=project(point,player,w,h,radius,Minimap:GetWidth(),Minimap:GetHeight(),facing)
    if not A.MiniHeat.InShape(x,y,Minimap:GetWidth(),Minimap:GetHeight(),shape) then x=nil end
   end
   if x then frame:SetScale(1/scale);frame:ClearAllPoints();frame:SetPoint('CENTER',Minimap,'CENTER',x*scale,y*scale);frame:Show() else frame:Hide() end
  end
 end
 self.driver:SetScript('OnUpdate',function(_,elapsed)
  if not next(self.frames) then self.elapsed=0;return end
  self.elapsed=self.elapsed+elapsed;if self.elapsed>=.05 then self.elapsed=0;self:Refresh() end
 end)
 return self
end
