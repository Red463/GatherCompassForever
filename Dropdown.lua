local _, A = ...
local S=A.Skin
local function options(button)
 return type(button.options)=='function' and button.options() or button.options
end
function S.CloseDropdown(owner)
 if not owner or S.dropdownOwner==owner then
  if S.dropdownMenu then S.dropdownMenu:Hide() end
  S.dropdownOwner=nil
 end
end
local function propagate(menu,value)
 if menu.SetPropagateKeyboardInput and (not InCombatLockdown or not InCombatLockdown()) then menu:SetPropagateKeyboardInput(value) end
end
local function focus(menu,index)
 local count=#menu.options;if count==0 then return end
 menu.focus=(index-1)%count+1
 for i,row in ipairs(menu.rows) do row.hovered=i==menu.focus;S.PaintButton(row) end
end
local function createMenu()
 if S.dropdownMenu then return S.dropdownMenu end
 local menu=S.Panel(UIParent);S.dropdownMenu=menu;menu.rows={};menu:Hide()
 menu:SetFrameStrata('FULLSCREEN_DIALOG');menu:SetFrameLevel(200);menu:SetClampedToScreen(true);menu:EnableMouse(true);menu:EnableKeyboard(true)
 menu:SetScript('OnHide',function()
  if S.dropdownOwner then S.dropdownOwner.menuOpen=false end
  S.dropdownOwner=nil
 end)
 local function outside()
  local owner=S.dropdownOwner
  if menu:IsShown() and owner and not menu:IsMouseOver() and not owner:IsMouseOver() then S.CloseDropdown() end
 end
 if pcall(menu.RegisterEvent,menu,'GLOBAL_MOUSE_DOWN') then
  menu:SetScript('OnEvent',function(_,event) if event=='GLOBAL_MOUSE_DOWN' then outside() end end)
 else
  menu:SetScript('OnUpdate',function(self)
   local down=IsMouseButtonDown and (IsMouseButtonDown('LeftButton') or IsMouseButtonDown('RightButton'))
   if down and not self.mouseDown then outside() end;self.mouseDown=down
  end)
 end
 menu:SetScript('OnKeyDown',function(self,key)
  local handled=key=='ESCAPE' or key=='DOWN' or key=='UP' or key=='ENTER' or key=='RETURN' or key=='SPACE'
  propagate(self,not handled)
  if key=='ESCAPE' then S.CloseDropdown()
  elseif key=='DOWN' then focus(self,(self.focus or 0)+1)
  elseif key=='UP' then focus(self,(self.focus or 1)-1)
  elseif key=='ENTER' or key=='RETURN' or key=='SPACE' then
   local owner=S.dropdownOwner;local item=self.options and self.options[self.focus or 1]
   if owner and item then owner:SelectValue(item.value) end
  end
 end)
 return menu
end
local function open(button)
 local menu=createMenu()
 if S.dropdownOwner==button and menu:IsShown() then S.CloseDropdown();return end
 S.CloseDropdown();S.dropdownOwner=button;button.menuOpen=true
 menu.options=options(button);menu.focus=1;menu.mouseDown=false
 menu:ClearAllPoints();menu:SetPoint('TOPLEFT',button,'BOTTOMLEFT',0,-2)
 menu:SetScale(button:GetEffectiveScale()/UIParent:GetEffectiveScale());menu:SetSize(button:GetWidth(),#menu.options*24+12)
 for i,item in ipairs(menu.options) do
  local row=menu.rows[i]
  if not row then
   row=S.Button(menu,'',function(self)
    local owner=S.dropdownOwner;if owner then owner:SelectValue(self.value) end
   end,'quiet');menu.rows[i]=row
   row.label:ClearAllPoints();row.label:SetPoint('LEFT',row,'LEFT',25,0);row.label:SetJustifyH('LEFT')
   row.check=row:CreateTexture(nil,'OVERLAY');row.check:SetTexture('Interface\\Buttons\\UI-CheckBox-Check');row.check:SetPoint('LEFT',row,'LEFT',3,0);row.check:SetSize(18,18)
  end
  row:ClearAllPoints();row:SetPoint('TOPLEFT',menu,'TOPLEFT',6,-6-(i-1)*24);row:SetSize(button:GetWidth()-12,24)
  row.label:SetSize(button:GetWidth()-45,22);row.value=item.value;row:SetText(item.label)
  local selected=item.value==button.value;S.Selected(row,selected)
  if selected then row.check:Show();menu.focus=i else row.check:Hide() end
  row:Show()
 end
 for i=#menu.options+1,#menu.rows do menu.rows[i]:Hide() end
 propagate(menu,true);menu:Show()
end
-- Ordinary Frame/Button primitives avoid version-specific dropdown intrinsics.
function S.Dropdown(parent,choices,onSelect,format)
 local b=CreateFrame('Button',nil,parent,'BackdropTemplate');b.options=choices;b.onSelect=onSelect;b.format=format;b.isDropdown=true
 b:SetSize(170,26);b:RegisterForClicks('LeftButtonUp')
 b:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 b:SetBackdropColor(unpack(S.fieldColor));b:SetBackdropBorderColor(unpack(S.panelEdge))
 b.label=S.Label(b,'',12,S.text);b.label:SetPoint('LEFT',b,'LEFT',10,0);b.label:SetPoint('RIGHT',b,'RIGHT',-28,0);b.label:SetHeight(22)
 b.caret=b:CreateTexture(nil,'ARTWORK');b.caret:SetTexture('Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up');b.caret:SetSize(22,22);b.caret:SetPoint('RIGHT',b,'RIGHT',-3,0)
 function b:SetValue(value)
  self.value=value;local text=self.format and self.format(value) or tostring(value or '')
  for _,item in ipairs(options(self)) do if item.value==value then text=item.label;break end end
  self.label:SetText(text)
 end
 function b:GetValue() return self.value end
 function b:SelectValue(value)
  if not self:IsEnabled() then return false end
  for _,item in ipairs(options(self)) do if item.value==value then
   local changed=self.value~=value;self:SetValue(value);S.CloseDropdown(self)
   if changed and self.onSelect then self.onSelect(value) end
   return true
  end end
  return false
 end
 b:SetScript('OnClick',function(self) if self:IsEnabled() then open(self) end end)
 b:HookScript('OnHide',function(self) S.CloseDropdown(self) end)
 b:HookScript('OnDisable',function(self) S.CloseDropdown(self);self.label:SetTextColor(unpack(S.dim));self.caret:SetAlpha(.4) end)
 b:HookScript('OnEnable',function(self) self.label:SetTextColor(unpack(S.text));self.caret:SetAlpha(1) end)
 b:HookScript('OnEnter',function(self) self:SetBackdropBorderColor(unpack(S.gold)) end)
 b:HookScript('OnLeave',function(self) self:SetBackdropBorderColor(unpack(S.panelEdge)) end)
 return b
end
