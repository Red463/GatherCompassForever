local _,A=...
local M={};A.MinimapButton=M
local function stopDrag(b)
 if b.dragging then
  b.dragging=false
  if b:GetScript('OnUpdate')==M.Drag then b:SetScript('OnUpdate',nil) end
 end
end
local function collected(b) return b:GetParent()~=Minimap end
local function angle()
 local value=A.db.settings.minimapAngle
 if not A.Store.Number(value) then value=225 end
 value=value%360;A.db.settings.minimapAngle=value;return value*math.pi/180
end
local function radii()
 return Minimap:GetWidth()/2+8,Minimap:GetHeight()/2+8
end
function M.Refresh()
 local b=M.frame;if not b or not A.db then return end
 b.db.hide=A.db.settings.minimapButton==false
 if b.db.hide then M.hiddenBySetting=true;stopDrag(b);b:Hide();return end
 if collected(b) then
  -- A button collector owns this parent, anchor, size and ordinary visibility.
  -- Only an explicit change to our own hide preference should show it again.
  stopDrag(b)
  if M.hiddenBySetting then M.hiddenBySetting=nil;b:Show() end
  return
 end
 M.hiddenBySetting=nil;b:SetSize(32,32)
 local radians=angle();local x,y=math.cos(radians),math.sin(radians);local rx,ry=radii()
 if GetMinimapShape and GetMinimapShape()=='SQUARE' then local edge=math.max(math.abs(x),math.abs(y));x,y=x/edge,y/edge end
 b:ClearAllPoints();b:SetPoint('CENTER',Minimap,'CENTER',x*rx,y*ry);b:Show()
end
function M.Drag()
 if not M.frame or not M.frame.dragging or not GetCursorPosition or not Minimap.GetCenter then return end
 if collected(M.frame) or A.db.settings.minimapButton==false then stopDrag(M.frame);return end
 local ok,cx,cy=pcall(Minimap.GetCenter,Minimap);local good,x,y=pcall(GetCursorPosition)
 local scale=Minimap:GetEffectiveScale()
 if not ok or not good or not A.Store.Number(cx) or not A.Store.Number(cy) or not A.Store.Number(x) or not A.Store.Number(y) or not A.Store.Number(scale) or scale<=0 then return end
 local rx,ry=radii();x,y=(x/scale-cx)/rx,(y/scale-cy)/ry
 if x==0 and y==0 then return end
 local radians
 if math.atan2 then radians=math.atan2(y,x)
 elseif x==0 then radians=y>0 and math.pi/2 or -math.pi/2
 else radians=math.atan(y/x);if x<0 then radians=radians+(y>=0 and math.pi or -math.pi) end end
 A.db.settings.minimapAngle=(radians*180/math.pi)%360;M.Refresh()
end
function M.Build()
 if M.frame then M.Refresh();return end
 if not CreateFrame or not Minimap or not A.db then return end
 local b=CreateFrame('Button','GatherlyMinimapButton',Minimap);M.frame=b
 -- Collectors conventionally inspect db.hide when discovering launchers.
 b.db={hide=A.db.settings.minimapButton==false}
 b:SetSize(32,32);b:SetFrameStrata('MEDIUM');b:SetFrameLevel(Minimap:GetFrameLevel()+8)
 b:EnableMouse(true);b:RegisterForClicks('LeftButtonUp');b:RegisterForDrag('LeftButton')
 b:SetHighlightTexture('Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight','ADD')
 -- Use the badge's own gold compass rim and transparent silhouette, rather
 -- than combining a clipped logo with an unrelated node-marker ring.
 b.icon=b:CreateTexture(nil,'ARTWORK');A.Skin.BrandBadge(b.icon);b.icon:SetAllPoints(b)
 b:SetScript('OnMouseDown',function(self,key) if key=='LeftButton' then self.wasDragged=false end end)
 b:SetScript('OnClick',function(self,key) if key=='LeftButton' and not self.wasDragged then A.UI.Toggle() end end)
 b:SetScript('OnDragStart',function(self)
  self.wasDragged=true
  if collected(self) or A.db.settings.minimapButton==false then stopDrag(self);return end
  self.dragging=true;self:SetScript('OnUpdate',M.Drag)
  if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
  M.Drag()
 end)
 b:SetScript('OnDragStop',function(self) if self.dragging then M.Drag() end;stopDrag(self) end)
 b:SetScript('OnEnter',function(self)
  if not GameTooltip or self.dragging then return end
  GameTooltip:SetOwner(self,'ANCHOR_LEFT');GameTooltip:SetText('Gatherly',1,.82,.35)
  GameTooltip:AddLine('Left-click to open or close the panel.',1,1,1)
  GameTooltip:AddLine(collected(self) and 'Position is managed by your minimap button collector.' or 'Drag to move around the minimap.',.75,.75,.75)
  GameTooltip:AddLine('Hide or show this button in Preferences.',.75,.75,.75);GameTooltip:Show()
 end)
 local function leave(self) if GameTooltip and (not GameTooltip.IsOwned or GameTooltip:IsOwned(self)) then GameTooltip:Hide() end end
 b:SetScript('OnLeave',leave)
 b:SetScript('OnHide',function(self) stopDrag(self);leave(self) end)
 b:SetScript('OnShow',function(self)
  if A.db.settings.minimapButton==false then self.db.hide=true;M.hiddenBySetting=true;self:Hide() end
 end)
 Minimap:HookScript('OnSizeChanged',M.Refresh);Minimap:HookScript('OnShow',M.Refresh)
 M.Refresh()
end
