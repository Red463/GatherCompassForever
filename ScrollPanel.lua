local _,A=...
local P={};A.ScrollPanel=P
function P.New(parent)
 local self={offset=0,maximum=0};self.frame=CreateFrame('Frame',nil,parent)
 local scroll=CreateFrame('ScrollFrame',nil,self.frame);self.scroll=scroll;scroll:SetPoint('TOPLEFT');scroll:SetClipsChildren(true)
 local body=CreateFrame('Frame',nil,scroll);self.body=body;scroll:SetScrollChild(body)
 local bar=A.Skin.Slider(self.frame,0,0,1,function(_,value) if not self.syncing then self:SetOffset(value) end end)
 self.bar=bar;bar:SetOrientation('VERTICAL');bar:SetThumbTexture('Interface\\Buttons\\UI-ScrollBar-Knob');bar.lowLabel:Hide();bar.highLabel:Hide()
 function self:SetOffset(value)
  local offset=math.max(0,math.min(self.maximum,value))
  if offset~=self.offset then
   local owner=A.Skin.dropdownOwner
   while owner do if owner==self.frame then A.Skin.CloseDropdown();break end;owner=owner:GetParent() end
  end
  self.offset=offset;scroll:SetVerticalScroll(self.offset)
  self.syncing=true;bar:SetValue(self.offset);self.syncing=false
 end
 function self:Layout(w,h,contentHeight)
  self.frame:SetSize(w,h);self.maximum=math.max(0,contentHeight-h)
  local width=w-(self.maximum>0 and 20 or 0);scroll:SetSize(width,h);body:SetSize(width,math.max(h,contentHeight))
  bar:ClearAllPoints();bar:SetPoint('TOPRIGHT',self.frame,'TOPRIGHT',0,-8);bar:SetSize(14,math.max(24,h-16))
  self.syncing=true;bar:SetMinMaxValues(0,self.maximum);self.syncing=false
  if self.maximum>0 then bar:Show() else bar:Hide() end
  scroll:UpdateScrollChildRect();self:SetOffset(self.offset);return width
 end
 local function wheel(_,delta) self:SetOffset(self.offset-delta*30) end
 scroll:EnableMouseWheel(true);scroll:SetScript('OnMouseWheel',wheel);bar:EnableMouseWheel(true);bar:SetScript('OnMouseWheel',wheel)
 return self
end
