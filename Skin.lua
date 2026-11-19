local addonName, A = ...
local S={media='Interface\\AddOns\\Gatherly\\Media\\',text={.94,.88,.75},muted={.72,.67,.57},dim={.56,.51,.43},gold={1,.82,.35},green={.35,.8,.35}}
-- Opaque warm greys keep inset panels close to the native marble background.
S.panelColor={.19,.18,.16,1}
S.fieldColor={.15,.145,.13,1}
S.panelEdge={.52,.48,.40,1}
S.bodyFont=STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF'
A.Skin=S
function S.Fill(parent,color,layer,sublevel)
 local t=parent:CreateTexture(nil,layer or 'BACKGROUND',nil,sublevel or 0); t:SetAllPoints(); t:SetColorTexture(unpack(color)); return t
end
function S.Panel(parent,color,edge,name)
 local f=CreateFrame('Frame',name,parent,'BackdropTemplate')
 f.opaqueBase=S.Fill(f,S.panelColor,'BACKGROUND',-8)
 f:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',
  edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 f:SetBackdropColor(unpack(S.panelColor)); f:SetBackdropBorderColor(unpack(S.panelEdge))
 if name then
  local trim=CreateFrame('Frame',nil,f,'BackdropTemplate'); trim:SetAllPoints(); trim:SetFrameLevel(f:GetFrameLevel()+30); trim:EnableMouse(false)
  trim:SetBackdrop({edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',edgeSize=20}); trim:SetBackdropBorderColor(1,1,1,1)
 end
 return f
end
local function object(value) return type(value)=='table' or type(value)=='userdata' end
function S.BrandBadge(texture)
 -- The supplied compass already has a border and transparent padding. Cropping
 -- its centre enlarges the leaf and cuts the compass points against the frame.
 texture:SetTexture(S.media..'EmptyEmblem');texture:SetTexCoord(0,1,0,1);texture:SetVertexColor(1,1,1,1)
end
function S.AddonVersion(fallback)
 local query=C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
 if type(query)=='function' then local ok,value=pcall(query,addonName,'Version');if ok and type(value)=='string' and value:find('%S') then return value end end
 return fallback
end
function S.Window(parent)
 local f=CreateFrame('Frame','GatherlyPanelChrome',parent,'PortraitFrameTemplate')
 f.opaqueBase=S.Fill(f,{.045,.038,.03,1},'BACKGROUND',-8)
 local version=S.AddonVersion(A.version)
 if f.SetTitle then f:SetTitle('Gatherly'..(type(version)=='string' and (' v'..version) or ' (development)')) end
 -- Tint only the native rock background; inset surfaces keep their own palette.
 if object(f.Bg) and type(f.Bg.SetVertexColor)=='function' then f.Bg:SetVertexColor(.85,.85,.85,1) end
 local portrait=f.portrait
 if not object(portrait) and object(f.PortraitContainer) then portrait=f.PortraitContainer.portrait end
 local container=object(f.PortraitContainer) and f.PortraitContainer or f
 if not object(portrait) then portrait=f:CreateTexture(nil,'ARTWORK') end
 -- Forever's portrait container is a 1px anchor, not the portrait bounds.
 portrait:ClearAllPoints();portrait:SetPoint('CENTER',container,'TOPLEFT',26,-24);portrait:SetSize(58,58)
 S.BrandBadge(portrait)
 if object(f.PortraitContainer) and object(f.PortraitContainer.CircleMask) then f.PortraitContainer.CircleMask:ClearAllPoints();f.PortraitContainer.CircleMask:SetAllPoints(portrait)
 elseif f.CreateMaskTexture and portrait.AddMaskTexture then local mask=f:CreateMaskTexture(nil,'ARTWORK');mask:SetTexture('Interface\\CharacterFrame\\TempPortraitAlphaMask');mask:SetAllPoints(portrait);portrait:AddMaskTexture(mask);f.brandMask=mask end
 f.brandPortrait=portrait
 if not object(f.CloseButton) then
  f.CloseButton=CreateFrame('Button',nil,f,'UIPanelCloseButton')
  f.CloseButton:SetPoint('TOPRIGHT',f,'TOPRIGHT',-3,-3); f.CloseButton:SetSize(32,32)
 end
 return f
end
function S.Label(parent,text,size,color,heading)
 local t=parent:CreateFontString(nil,'OVERLAY')
 t:SetFont(heading and 'Fonts\\FRIZQT__.TTF' or S.bodyFont,math.max(11,size or 12),'')
 t:SetShadowColor(0,0,0,1);t:SetShadowOffset(1,-1)
 t:SetTextColor(unpack(color or S.text)); t:SetJustifyH('LEFT'); t:SetJustifyV('MIDDLE'); t:SetWordWrap(false)
 t:SetText(text or ''); return t
end
function S.PaintButton(b)
 if b.nativeTab then
  if b.selected then if PanelTemplates_SelectTab then PanelTemplates_SelectTab(b) end
  else if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(b) end end
  b.label:SetTextColor(unpack(b.selected and S.text or S.gold)); return
 end
 local fill,edge,text,state
 if not b:IsEnabled() then fill,edge,text,state={.18,.17,.15,1},{.2,.18,.15,1},{.4,.37,.31},'disabled'
 elseif b.pressed then fill,edge,text,state={.18,.12,.08,1},{.62,.49,.29,1},S.gold,'pressed'
 elseif b.hovered then fill,edge,text,state={.30,.24,.16,1},{.75,.61,.37,1},S.text,'hover'
 elseif b.selected then fill,edge,text,state={.27,.21,.12,1},{.71,.56,.29,1},S.gold,'selected'
 else fill,edge,text,state={0,0,0,0},{.32,.27,.20,1},S.gold,'normal' end
 b.label:SetTextColor(unpack(b:IsEnabled() and b.labelColor or text)); b.paintState=state
 if b.nativeAction then return end
 b.background:SetColorTexture(unpack(fill))
 if b.highlight then if b.hovered or b.selected then b.highlight:Show() else b.highlight:Hide() end end
 if b.accent then if b.selected then b.accent:Show() else b.accent:Hide() end end
end
function S.Button(parent,text,callback,style)
 local native=style~='quiet' and style~='card'
 local b=CreateFrame('Button',nil,parent,native and 'UIPanelButtonTemplate' or nil); b.style=style; b.nativeAction=native
 b:RegisterForClicks('LeftButtonUp')
 if not native then
  b.background=S.Fill(b,{0,0,0,0},'BACKGROUND')
  b.highlight=b:CreateTexture(nil,'ARTWORK'); b.highlight:SetAllPoints(); b.highlight:SetTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight'); b.highlight:SetBlendMode('ADD'); b.highlight:SetAlpha(.3)
 end
 b.label=S.Label(b,text,12); b.label:SetPoint('LEFT',4,0); b.label:SetPoint('RIGHT',-4,0); b.label:SetJustifyH('CENTER')
 b:SetFontString(b.label); b:SetText(text or '')
 local hook=native and 'HookScript' or 'SetScript'
 b:SetScript('OnClick',callback)
 b[hook](b,'OnEnter',function(self) self.hovered=true; S.PaintButton(self) end)
 b[hook](b,'OnLeave',function(self) self.hovered=false; self.pressed=false; S.PaintButton(self) end)
 b[hook](b,'OnMouseDown',function(self,key) if key=='LeftButton' then self.pressed=true; S.PaintButton(self) end end)
 b[hook](b,'OnMouseUp',function(self) self.pressed=false; S.PaintButton(self) end)
 b[hook](b,'OnEnable',function(self) S.PaintButton(self) end)
 b[hook](b,'OnDisable',function(self) self.pressed=false; S.PaintButton(self) end)
 b[hook](b,'OnHide',function(self) self.hovered=false; self.pressed=false; S.PaintButton(self) end)
 S.PaintButton(b); return b
end
function S.Tab(parent,text,width,callback,top)
 S.tabCount=(S.tabCount or 0)+1
 local ok,b=pcall(CreateFrame,'Button','GatherlyTab'..S.tabCount,parent,top and 'PanelTopTabButtonTemplate' or 'PanelTabButtonTemplate')
 local native=ok and object(b)
 for _,key in ipairs({'Text','Left','Middle','Right','LeftActive','MiddleActive','RightActive'}) do
  if not native or not object(b[key]) then native=false;break end
 end
 if not native then
  if ok and object(b) then b:Hide() end
  b=S.Button(parent,text,callback,'quiet');b.tabFallback=true;b:SetSize(width,28);return b
 end
 b.nativeTab=true
 b:SetText(text); b:SetSize(width,32)
 local label=b:GetFontString()
 if not object(label) then label=S.Label(b,text,12,S.gold);b:SetFontString(label) end
 label:ClearAllPoints();label:SetPoint('CENTER',b,'CENTER',0,0);label:SetSize(width-16,24);label:SetJustifyH('CENTER')
 b.label=label; b:SetScript('OnClick',callback)
 if PanelTemplates_TabResize then
  PanelTemplates_TabResize(b,0,width)
  b:HookScript('OnShow',function(self) PanelTemplates_TabResize(self,0,width) end)
 end
 return b
end
function S.Check(parent,text,callback)
 S.checkCount=(S.checkCount or 0)+1
 local b=CreateFrame('CheckButton','GatherlyCheck'..S.checkCount,parent,'UICheckButtonTemplate'); b:SetSize(24,24)
 b.label=S.Label(b,text,13,S.text); b.label:SetPoint('LEFT',b,'RIGHT',4,0); b.label:SetSize(330,24)
 b:SetScript('OnClick',callback)
 b:HookScript('OnDisable',function(self) self.label:SetTextColor(unpack(S.dim)) end)
 b:HookScript('OnEnable',function(self) self.label:SetTextColor(unpack(S.text)) end)
 return b
end
function S.Slider(parent,lo,hi,step,callback,format)
 S.sliderCount=(S.sliderCount or 0)+1
 local name='GatherlySlider'..S.sliderCount
 -- Use the built-in slider widget with Classic Blizzard art. The legacy
 -- OptionsSliderTemplate is absent/broken on some current clients.
 local f=CreateFrame('Slider',name,parent,'BackdropTemplate');f:SetOrientation('HORIZONTAL');f:SetSize(270,18)
 f:EnableMouse(true);f:SetHitRectInsets(0,0,-8,-8)
 f:SetBackdrop({bgFile='Interface\\Buttons\\UI-SliderBar-Background',edgeFile='Interface\\Buttons\\UI-SliderBar-Border',tile=true,tileSize=8,edgeSize=8,insets={left=3,right=3,top=3,bottom=3}})
 f:SetThumbTexture('Interface\\Buttons\\UI-SliderBar-Button-Horizontal')
 local thumb=f:GetThumbTexture();if object(thumb) then thumb:SetSize(32,32) end
 f:SetMinMaxValues(lo,hi); f:SetValueStep(step); f:SetObeyStepOnDrag(true)
 f.lowLabel=S.Label(f,format and format(lo) or tostring(lo),11,S.muted);f.lowLabel:SetPoint('TOPLEFT',f,'BOTTOMLEFT',0,-3);f.lowLabel:SetSize(55,15)
 f.highLabel=S.Label(f,format and format(hi) or tostring(hi),11,S.muted);f.highLabel:SetPoint('TOPRIGHT',f,'BOTTOMRIGHT',0,-3);f.highLabel:SetSize(55,15);f.highLabel:SetJustifyH('RIGHT')
 f:SetScript('OnValueChanged',callback);return f
end
function S.Selected(b,on) b.selected=not not on; S.PaintButton(b) end
function S.Edit(parent,width)
 local e=CreateFrame('EditBox',nil,parent,'BackdropTemplate'); e:SetSize(width or 250,29)
 e:SetBackdrop({bgFile='Interface\\Buttons\\WHITE8X8',edgeFile='Interface\\Tooltips\\UI-Tooltip-Border',edgeSize=12,insets={left=3,right=3,top=3,bottom=3}})
 e:SetBackdropColor(unpack(S.fieldColor)); e:SetBackdropBorderColor(unpack(S.panelEdge))
 e:SetFont(S.bodyFont,13,''); e:SetTextColor(unpack(S.text)); e:SetTextInsets(10,10,0,0); e:SetAutoFocus(false); e:SetMaxLetters(80)
 e:SetScript('OnEscapePressed',function(self) self:ClearFocus() end); e:SetScript('OnEnterPressed',function(self) self:ClearFocus() end)
 return e
end
function S.FitWindow(frame,width,height)
 local vw,vh=UIParent:GetWidth(),UIParent:GetHeight()
 local scale=math.min(1,math.max(1,vw-24)/width,math.max(1,vh-24)/height)
 frame:SetSize(width,height); frame:SetScale(scale); return scale
end
function S.Image(parent,name,width,height,layer)
 local t=parent:CreateTexture(nil,layer or 'ARTWORK'); t:SetTexture(S.media..name); t:SetSize(width,height); return t
end
function S.Hint(frame,title,body)
 frame:HookScript('OnEnter',function(self)
  if GameTooltip then GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(title); GameTooltip:AddLine(type(body)=='function' and body() or body,.72,.80,.72,true); GameTooltip:Show() end
 end)
 frame:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
end
