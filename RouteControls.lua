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
 local S=A.Skin;local f=CreateFrame('Frame',nil,UIParent,'BackdropTemplate');C.frame=f
 f:SetSize(272,64);f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true);f:SetMovable(true);f:EnableMouse(true)
 f.opaqueBase=S.Fill(f,{.045,.038,.03,1},'BACKGROUND',-8)
 -- Reuse the main native frame's stone artwork, with the same tint. The
 -- dialog texture is a Classic fallback when the native background is absent.
 local source=A.UI and A.UI.chrome and A.UI.chrome.Bg
 local object=type(source)=='table' or type(source)=='userdata'
 local texture=object and type(source.GetTexture)=='function' and source:GetTexture()
 local native=type(texture)=='string' or type(texture)=='number'
 C.background=f:CreateTexture(nil,'BACKGROUND');C.background:SetAllPoints()
 C.background:SetTexture(native and texture or 'Interface\\DialogFrame\\UI-DialogBox-Background')
 if native and type(source.GetTexCoord)=='function' then C.background:SetTexCoord(source:GetTexCoord()) end
 C.background:SetVertexColor(.85,.85,.85,1)
 f:SetBackdrop({edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=16});f:SetBackdropBorderColor(1,1,1,1)
 local bar=CreateFrame('Frame',nil,f);C.titlebar=bar
 bar:SetPoint('TOPLEFT',f,'TOPLEFT',8,-5);bar:SetSize(256,22);bar:EnableMouse(true);bar:RegisterForDrag('LeftButton')
 local header=bar:CreateTexture(nil,'BACKGROUND');header:SetAllPoints();header:SetTexture('Interface\\DialogFrame\\UI-DialogBox-Background');header:SetVertexColor(.65,.5,.35,1)
 local rule=bar:CreateTexture(nil,'BORDER');rule:SetColorTexture(.48,.36,.19,1);rule:SetPoint('BOTTOMLEFT',bar,'BOTTOMLEFT',0,0);rule:SetSize(256,1)
 local title=S.Label(bar,'Gatherly',13,S.gold);title:SetPoint('CENTER',bar,'CENTER',0,0);title:SetSize(248,20);title:SetJustifyH('CENTER')
 local function finish()
  if C.dragging then f:StopMovingOrSizing();C.dragging=false;C.SavePosition() end
 end
 bar:SetScript('OnDragStart',function() C.dragging=true;f:StartMoving() end)
 bar:SetScript('OnDragStop',finish);f:SetScript('OnHide',function() finish();S.CloseDropdown(C.colour) end)
 f:RegisterEvent('DISPLAY_SIZE_CHANGED');f:RegisterEvent('UI_SCALE_CHANGED')
 f:SetScript('OnEvent',function() finish();C.Position() end)
 S.Hint(bar,'Route controls','Drag this heading to move the panel. Its position is remembered.')
 for _,spec in ipairs({{'stop','Stop',10,64},{'open','Open panel',78,86},{'skip','Skip >',168,58}}) do
  local key=spec[1]
  local b=S.Button(f,spec[2],function()
   if key=='open' then A.UI.OpenRoutes() else A.UI.actions[key]() end
  end)
  b:SetPoint('TOPLEFT',f,'TOPLEFT',spec[3],-32);b:SetSize(spec[4],24);C[key]=b
 end
 S.Hint(C.stop,'Stop route','Stop guidance and hide the route controls.')
 S.Hint(C.open,'Open panel','Open Gatherly on the Routes page without stopping guidance.')
 S.Hint(C.skip,'Skip next node','Advance to the next route waypoint. Corridor routes use points along the farming path.')
 C.colour=S.Dropdown(f,A.Resources.HeatColours,function(value)
  A.Resources.Settings(A.db.settings).miniHeatColour=value;C.Update(A.follower)
  if A.Map then A.Map.Refresh(A.db,A.UI.DisplayRoute(),A.follower) end
 end)
 C.colour:SetPoint('TOPLEFT',f,'TOPLEFT',232,-32);C.colour:SetSize(26,24);C.colour.menuWidth=156
 C.colour.label:Hide();C.colour.caret:Hide()
 C.swatch=C.colour:CreateTexture(nil,'ARTWORK');C.swatch:SetPoint('CENTER',C.colour,'CENTER',0,0);C.swatch:SetSize(14,14)
 S.Hint(C.colour,'Minimap route colour','Choose a colour that stands out against the terrain. Applies immediately to minimap Lines and Heatmap, without restarting guidance. Opacity is set in Node display. Amber is the default colour.')
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
