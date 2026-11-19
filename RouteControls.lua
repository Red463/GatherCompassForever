local _,A=...
local C={};A.RouteControls=C
local function clamp(n,lo,hi) return math.max(lo,math.min(hi,n)) end
function C.Position()
 local f=C.frame;if not f then return end
 local w,h=UIParent:GetWidth(),UIParent:GetHeight()
 if not A.Store.Number(w) or not A.Store.Number(h) or w<=0 or h<=0 then return end
 local p=A.db.settings.routeControlsPosition
 local x,y=.5,120/h
 if type(p)=='table' and A.Store.Number(p.x) and A.Store.Number(p.y) then x,y=p.x,p.y end
 local mx,my=math.min(w/2,f:GetWidth()/2+8),math.min(h/2,f:GetHeight()/2+8)
 f:ClearAllPoints();f:SetPoint('CENTER',UIParent,'BOTTOMLEFT',clamp(x*w,mx,w-mx),clamp(y*h,my,h-my))
end
function C.SavePosition()
 local x,y=C.frame:GetCenter();local w,h=UIParent:GetWidth(),UIParent:GetHeight()
 if A.Store.Number(x) and A.Store.Number(y) and A.Store.Number(w) and A.Store.Number(h) and w>0 and h>0 then
  A.db.settings.routeControlsPosition={x=clamp(x/w,0,1),y=clamp(y/h,0,1)}
 end
end
function C.Build()
 if C.frame then return C.frame end
 local S=A.Skin;local f=S.Panel(UIParent);C.frame=f
 f:SetSize(344,116);f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true)
 local bar=CreateFrame('Frame',nil,f);C.titlebar=bar
 bar:SetPoint('TOPLEFT',f,'TOPLEFT',8,-5);bar:SetSize(328,30);bar:EnableMouse(true);bar:RegisterForDrag('LeftButton')
 local title=S.Label(bar,'Gatherly - Route controls',13,S.gold);title:SetPoint('LEFT',bar,'LEFT',4,0);title:SetSize(320,24)
 local function finish()
  if C.dragging then f:StopMovingOrSizing();C.dragging=false;C.SavePosition() end
 end
 bar:SetScript('OnDragStart',function() C.dragging=true;f:StartMoving() end)
 bar:SetScript('OnDragStop',finish);f:SetScript('OnHide',function() finish();S.CloseDropdown(C.colour) end)
 f:RegisterEvent('DISPLAY_SIZE_CHANGED');f:RegisterEvent('UI_SCALE_CHANGED')
 f:SetScript('OnEvent',function() finish();C.Position() end)
 S.Hint(bar,'Route controls','Drag this heading to move the panel. Its position is remembered.')
 for _,spec in ipairs({{'stop','Stop route',10,100},{'open','Open panel',116,100},{'skip','Skip next node',222,112}}) do
  local key=spec[1]
  local b=S.Button(f,spec[2],function()
   if key=='open' then A.UI.OpenRoutes() else A.UI.actions[key]() end
  end)
  b:SetPoint('TOPLEFT',f,'TOPLEFT',spec[3],-42);b:SetSize(spec[4],26);C[key]=b
 end
 S.Hint(C.skip,'Skip next node','Advance to the next route waypoint. Corridor routes use points along the farming path.')
 local label=S.Label(f,'Heatmap colour',12,S.text);label:SetPoint('TOPLEFT',f,'TOPLEFT',12,-78);label:SetSize(112,26)
 C.colour=S.Dropdown(f,A.Resources.HeatColours,function(value)
  A.Resources.Settings(A.db.settings).miniHeatColour=value;C.Update(A.follower)
  if A.Map then A.Map.Refresh(A.db,A.UI.DisplayRoute(),A.follower) end
 end)
 C.colour:SetPoint('TOPLEFT',f,'TOPLEFT',132,-78);C.colour:SetSize(202,26)
 C.colour.label:ClearAllPoints();C.colour.label:SetPoint('LEFT',C.colour,'LEFT',32,0);C.colour.label:SetPoint('RIGHT',C.colour,'RIGHT',-28,0);C.colour.label:SetHeight(22)
 C.swatch=C.colour:CreateTexture(nil,'ARTWORK');C.swatch:SetPoint('LEFT',C.colour,'LEFT',10,0);C.swatch:SetSize(14,14)
 S.Hint(C.colour,'Minimap heatmap colour','Choose a colour that stands out against the terrain. Applies immediately to minimap heat only, without restarting guidance. Opacity is set in Node display. Amber restores the original tint.')
 C.Position();f:Hide();return f
end
function C.Update(follower)
 local active=follower and (follower.status=='running' or follower.status=='paused' or follower.status=='suspended')
 if not active or not A.db or A.db.settings.routeControls==false then
  if C.frame then C.frame:Hide() end;return
 end
 local f=C.Build();C.skip:SetEnabled(follower:Target()~=nil)
 local choice=A.Resources.HeatColour(A.Resources.Settings(A.db.settings).miniHeatColour)
 C.colour:SetValue(choice.value);C.swatch:SetColorTexture(unpack(choice.swatch or choice.rgb));f:Show()
end
