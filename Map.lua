local _, A = ...
local M={pins={},byKey={},worldLines={},worldShadows={},miniLines={}}; A.Map=M
local positionHandle,paintHandle
function M.SetNodeFocus(mapID,materials,nodeKey,source)
 if mapID==nil then M.nodeFocus=nil;return true end
 if not A.Store.Number(mapID) or mapID<=0 or mapID%1~=0 or type(materials)~='table' or not WorldMapFrame then return nil,'World-map focus unavailable.' end
 source=source or 'combined'
 if source~='combined' and source~='confirmed' and source~='imported' then return nil,'Invalid node source.' end
 local ids={};for id,on in pairs(materials) do if type(id)=='string' and #id<=100 and on==true then ids[id]=true end end
 if not next(ids) then return nil,'No resource selected.' end
 if M.focusMap~=WorldMapFrame then
  WorldMapFrame:HookScript('OnHide',function() M.nodeFocus=nil end);M.focusMap=WorldMapFrame
 end
 M.nodeFocus={mapID=mapID,materials=ids,nodeKey=type(nodeKey)=='string' and nodeKey or nil,source=source};return true
end
function M.Project(p,w,h) return p.x*w,-p.y*h end
local function miniRaw(p,player,w,h,radius,mw,mh,facing)
 local dx=(p.x-player.x)*w; local north=(player.y-p.y)*h
 local c,s=math.cos(facing or 0),math.sin(facing or 0)
 return (dx*c+north*s)/radius*mw/2,(-dx*s+north*c)/radius*mh/2
end
function M.MiniProject(p,player,w,h,radius,mw,mh,facing)
 local x,y=miniRaw(p,player,w,h,radius,mw,mh,facing)
 if (x/(mw/2))^2+(y/(mh/2))^2>.90^2 then return nil end
 return x,y
end
function M.Clip(x1,y1,x2,y2,mw,mh)
 -- Clip in a conservative ellipse inside any supported minimap shape.
 local rx,ry=mw*.44,mh*.44
 local ax,ay=x1/rx,y1/ry; local dx,dy=(x2-x1)/rx,(y2-y1)/ry
 local aa=dx*dx+dy*dy; if aa==0 then if ax*ax+ay*ay<=1 then return x1,y1,x2,y2 end; return end
 local bb=2*(ax*dx+ay*dy); local cc=ax*ax+ay*ay-1; local disc=bb*bb-4*aa*cc
 if disc<0 then return end
 local l=math.max(0,(-bb-math.sqrt(disc))/(2*aa)); local r=math.min(1,(-bb+math.sqrt(disc))/(2*aa))
 if l>r then return end
 return x1+(x2-x1)*l,y1+(y2-y1)*l,x1+(x2-x1)*r,y1+(y2-y1)*r
end
-- Subtract circular clear areas in minimap pixels. Native tracking dots are
-- not addon pins: leave actual gaps rather than relying on their draw order.
function M.GapSegments(x1,y1,x2,y2,holes,padding)
 local dx,dy=x2-x1,y2-y1; local length2=dx*dx+dy*dy
 if length2<.000001 then return {} end
 local cuts={}
 for _,hole in ipairs(holes) do
  local hx,hy=hole.x-x1,hole.y-y1
  local midpoint=(hx*dx+hy*dy)/length2
  local cross=hx*dy-hy*dx
  local radius=hole.r+(padding or 0)
  local discriminant=radius*radius-cross*cross/length2
  if discriminant>0 then
   local span=math.sqrt(discriminant/length2)
   local lo,hi=math.max(0,midpoint-span),math.min(1,midpoint+span)
   if lo<hi then cuts[#cuts+1]={lo,hi} end
  end
 end
 table.sort(cuts,function(a,b) return a[1]<b[1] end)
 local pieces={}; local cursor=0
 local function piece(lo,hi)
  if (hi-lo)*(hi-lo)*length2>=1 then
   pieces[#pieces+1]={x1+dx*lo,y1+dy*lo,x1+dx*hi,y1+dy*hi}
  end
 end
 for _,cut in ipairs(cuts) do
  if cut[1]>cursor then piece(cursor,cut[1]) end
  cursor=math.max(cursor,cut[2]); if cursor>=1 then break end
 end
 if cursor<1 then piece(cursor,1) end
 return pieces
end
function M.Cursor(allowOutside)
 local map=WorldMapFrame; if not map or not map.ScrollContainer or not map.ScrollContainer.GetNormalizedCursorPosition then return nil end
 local x,y=map.ScrollContainer:GetNormalizedCursorPosition()
 if not A.Store.Number(x) or not A.Store.Number(y) then return end
 local p={mapID=map:GetMapID(),x=x,y=y}
 if A.Store.Position(p) or allowOutside and A.Store.Number(p.mapID) and p.mapID>0 and p.mapID%1==0 then return p end
end
function M.AddAtCursor()
 local p=M.Cursor(); if not M.editor or not p then return false end
 p.kind='travel'; local added=M.editor:Add(p)
 if added then A.editIndex=#M.editor.draft.points; if A.UI then A.UI.Refresh() end end
 return added
end
function M.MoveAtCursor(i)
 local p=M.Cursor(); if not M.editor or not p then return false end
 return M.editor:Move(i,p)
end
function M.CancelDrag()
 local frame=M.dragFrame;M.dragIndex=nil;M.dragFrame=nil;M.dragPoint=nil;M.dragEditor=nil;M.dragLinks=nil
 if frame then frame:SetScript('OnUpdate',nil);if paintHandle then paintHandle(frame) end end
end
function M.CollectDragLinks()
 if not M.dragPoint then return end
 M.dragLinks={}
 for _,l in ipairs(M.worldLines) do if l:IsShown() and (l.fromPoint==M.dragPoint or l.toPoint==M.dragPoint) then M.dragLinks[#M.dragLinks+1]=l end end
end
function M.UpdateDrag()
 local map=WorldMapFrame;local editor=M.editor;local frame=M.dragFrame
 if not frame then return end
 if editor~=M.dragEditor or not editor or editor.draft.points[M.dragIndex]~=M.dragPoint or not map:IsShown() or map:GetMapID()~=editor.draft.mapID then M.CancelDrag();return end
 local p=M.Cursor(true);if not p then return end
 p.x=math.max(0,math.min(1,p.x+(M.dragOffsetX or 0)));p.y=math.max(0,math.min(1,p.y+(M.dragOffsetY or 0)))
 if not editor:Move(M.dragIndex,p) then M.CancelDrag();return end
 positionHandle(frame)
 local canvas=map:GetCanvas();local w,h=canvas:GetWidth(),canvas:GetHeight()
 for _,l in ipairs(M.dragLinks or {}) do
  l:SetStartPoint('TOPLEFT',canvas,l.fromPoint.x*w,-l.fromPoint.y*h)
  l:SetEndPoint('TOPLEFT',canvas,l.toPoint.x*w,-l.toPoint.y*h)
  if l.shadow then
   l.shadow:SetStartPoint('TOPLEFT',canvas,l.fromPoint.x*w,-l.fromPoint.y*h)
   l.shadow:SetEndPoint('TOPLEFT',canvas,l.toPoint.x*w,-l.toPoint.y*h)
  end
 end
end
function M.StartDrag(frame)
 local p=M.Cursor();local point=M.editor and M.editor.draft.points[frame.index]
 if not p or not point or p.mapID~=M.editor.draft.mapID then return end
 M.CancelDrag();A.editIndex=frame.index;frame.wasDragged=true
 M.dragFrame=frame;M.dragIndex=frame.index;M.dragEditor=M.editor;M.dragPoint=point
 M.dragOffsetX,M.dragOffsetY=point.x-p.x,point.y-p.y
 if A.db then M.Refresh(A.db,M.editor.draft,nil) end
 M.CollectDragLinks();frame:SetScript('OnUpdate',M.UpdateDrag)
 if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(frame) then GameTooltip:Hide() end
 paintHandle(frame)
end
function M.EndDrag()
 M.UpdateDrag();M.CancelDrag()
 if A.db and M.editor then M.Refresh(A.db,M.editor.draft,nil) end
 if A.UI then A.UI.Refresh() end
end
function M.UpdateEditorHelp()
 local map=WorldMapFrame;local visible=M.editor and map and map:IsShown() and map:GetMapID()==M.editor.draft.mapID
 if M.editorHelp then
  if visible then M.editorHelp:Show();M.editorHelp.save:SetEnabled(#M.editor.draft.points>0) else M.editorHelp:Hide() end
 end
end
function M.RaiseEditor()
 if not M.editor or not M.editLayer or not WorldMapFrame then return end
 local level=math.max(WorldMapFrame:GetCanvas():GetFrameLevel()+20,M.worldRouteLayer and M.worldRouteLayer:GetFrameLevel()+10 or 0)
 if WorldMapFrame.GetPinFrameLevelsManager then
  local ok,manager=pcall(WorldMapFrame.GetPinFrameLevelsManager,WorldMapFrame)
  if ok and manager and type(manager.GetValidFrameLevel)=='function' then
   local good,top=pcall(manager.GetValidFrameLevel,manager,'PIN_FRAME_LEVEL_TOPMOST',1000000)
   if good and A.Store.Number(top) then level=math.max(level,top+10) end
  end
 end
 for _,pin in ipairs(M.pins) do if pin.wanted and not pin.mini and not pin.editorHandle then level=math.max(level,pin:GetFrameLevel()+10) end end
 M.editLayer:SetFrameLevel(level)
 if M.editorHelp then M.editorHelp:SetFrameLevel(level+10);M.editorHelp.save:SetFrameLevel(level+12);M.editorHelp.back:SetFrameLevel(level+12) end
end
function M.SetEditor(e)
 M.CancelDrag();M.nodeFocus=nil
 for _,p in ipairs(M.pins) do if p.editorHandle and p.key then M.byKey[p.key]=nil;p.key=nil;p.signature=nil;p.editorHandle=nil;p:Hide();p:SetParent(UIParent) end end
 M.editor=e
 if not CreateFrame or not WorldMapFrame then return end
 if not M.editLayer then
  local parent=WorldMapFrame:GetCanvas(); local layer=CreateFrame('Frame',nil,parent); M.editLayer=layer
  layer:SetAllPoints(parent); layer:SetFrameLevel(parent:GetFrameLevel()+20); layer:EnableMouse(true)
  layer:SetScript('OnMouseDown',function(self,button) self.addPressed=button=='LeftButton' end)
  layer:SetScript('OnMouseUp',function(self,button) local pressed=self.addPressed;self.addPressed=false;if button=='LeftButton' and pressed and not M.dragFrame then
   if M.AddAtCursor() and A.db then M.Refresh(A.db,M.editor.draft,nil) end
  end end)
  layer:SetScript('OnHide',function(self) self.addPressed=false;M.CancelDrag() end)
  WorldMapFrame:HookScript('OnHide',function() M.CancelDrag();M.UpdateEditorHelp() end)
 end
 if not M.editorHelp and A.Skin then
  local parent=WorldMapFrame.ScrollContainer or WorldMapFrame;local s=A.Skin
  local help=s.Panel(parent);M.editorHelp=help;help:SetSize(math.min(640,math.max(300,parent:GetWidth()-20)),76)
  help:SetPoint('BOTTOMLEFT',parent,'BOTTOMLEFT',10,10);help:SetFrameLevel(parent:GetFrameLevel()+50);help:EnableMouse(true)
  local heading=s.Label(help,'EDIT ROUTE / UNSAVED DRAFT',12,s.gold);heading:SetPoint('TOPLEFT',help,'TOPLEFT',12,-9);heading:SetSize(help:GetWidth()-152,18)
  help.instructions=s.Label(help,'Drag circles to move waypoints. Click empty map to add. Save when finished.',11,s.text)
  help.instructions:SetPoint('TOPLEFT',help,'TOPLEFT',12,-31);help.instructions:SetSize(help:GetWidth()-152,36);help.instructions:SetWordWrap(true)
  help.save=s.Button(help,'Save route',function()
   if A.UI then A.UI.actions.save();if not M.editor then WorldMapFrame:Hide();A.UI.OpenRoutes() end end
  end);help.save:SetPoint('TOPRIGHT',help,'TOPRIGHT',-10,-8);help.save:SetSize(116,24)
  help.back=s.Button(help,'Route panel',function() WorldMapFrame:Hide();if A.UI then A.UI.OpenRoutes() end end)
  help.back:SetPoint('TOPRIGHT',help,'TOPRIGHT',-10,-41);help.back:SetSize(116,24)
 end
 if e then M.editLayer:Show() else M.editLayer:Hide() end
 M.RaiseEditor()
 M.UpdateEditorHelp()
end
local function line(pool,i,parent,x1,y1,x2,y2,color,center,drawLayer)
 local l=pool[i]; if not l then l=parent:CreateLine(nil,drawLayer or 'OVERLAY'); pool[i]=l end
 l:SetColorTexture(color[1],color[2],color[3],color[4] or 1); l:SetThickness(color[5] or 2)
 l:SetStartPoint(center and 'CENTER' or 'TOPLEFT',parent,x1,y1); l:SetEndPoint(center and 'CENTER' or 'TOPLEFT',parent,x2,y2); l:Show()
end
local gold={1,.78,.22,1,4}; local teal={.2,.85,.72,.85,2}; local done={.45,.5,.55,.5,2}
function M.WorldRouteLayer(canvas)
 if not canvas then return end
 local layer=M.worldRouteLayer
 if not layer then layer=CreateFrame('Frame',nil,canvas);M.worldRouteLayer=layer;layer:EnableMouse(false) end
 if layer:GetParent()~=canvas then layer:SetParent(canvas) end
 layer:ClearAllPoints();layer:SetAllPoints(canvas)
 local level=canvas:GetFrameLevel()+10
 if WorldMapFrame.GetPinFrameLevelsManager then
  local ok,manager=pcall(WorldMapFrame.GetPinFrameLevelsManager,WorldMapFrame)
  if ok and (type(manager)=='table' or type(manager)=='userdata') and type(manager.GetFrameLevelStart)=='function' then
   -- Exploration and highlight artwork are pins too. The minimum pin tier
   -- places routes beneath that artwork, even when above detail-layer tiles.
   for _,kind in ipairs({'PIN_FRAME_LEVEL_DEFAULT','PIN_FRAME_LEVEL_MAP_EXPLORATION','PIN_FRAME_LEVEL_MAP_HIGHLIGHT'}) do
    local good,base=pcall(manager.GetFrameLevelStart,manager,kind)
    if good and A.Store.Number(base) then
     local range=1
     if type(manager.GetFrameLevelRange)=='function' then
      local valid,value=pcall(manager.GetFrameLevelRange,manager,kind)
      if valid and A.Store.Number(value) and value>=1 then range=value end
     end
     level=math.max(level,base+range)
    end
   end
  end
 end
 -- OpenMap can put stitched terrain above the normal map-art tiers.
 local api=OpenMapAPI
 if type(api)=='table' and api.major==1 and type(api.IsStitched)=='function' and type(api.ArtTopLevel)=='function' then
  local ok,active=pcall(api.IsStitched)
  if ok and active then
   local good,top=pcall(api.ArtTopLevel)
   if good and A.Store.Number(top) then level=math.max(level,top+1) end
  end
 end
 layer:SetFrameLevel(level);layer:Show();return layer
end
local function hide(pool) for _,f in ipairs(pool) do f:Hide() end end
local function pinsLib() return LibStub and LibStub('HereBeDragons-Pins-2.0',true) end
local function hideTooltip(self)
 if GameTooltip and (not GameTooltip.IsOwned or GameTooltip:IsOwned(self)) then GameTooltip:Hide() end
end
paintHandle=function(f)
 if not f.editorHandle then return end
 local zoom=WorldMapFrame.GetCanvasScale and WorldMapFrame:GetCanvasScale() or 1
 if not A.Store.Number(zoom) or zoom<=0 then zoom=1 end
 local selected=f.index==A.editIndex or f==M.dragFrame or f.hovered
 local size=selected and math.max(22,#tostring(f.index)*6+6) or 12
 f:SetSize(math.max(24,size)/zoom,math.max(24,size)/zoom)
 f.icon:SetSize(size/zoom,size/zoom);f.icon:SetVertexColor(1,selected and .84 or .68,selected and .35 or .20,1)
 f.background:SetSize((size-3)/zoom,(size-3)/zoom);f.background:Show()
 f.number:SetSize(size/zoom,size/zoom)
 f.number:SetFont(STANDARD_TEXT_FONT or 'Fonts\\FRIZQT__.TTF',10/zoom,'OUTLINE');f.number:SetText(tostring(f.index))
 if selected then f.number:Show() else f.number:Hide() end
 f:SetFrameLevel(M.editLayer:GetFrameLevel()+(selected and 3 or 2))
end
positionHandle=function(f)
 local point=M.editor and M.editor.draft.points[f.index];if not point then return end
 local canvas=WorldMapFrame:GetCanvas();f:ClearAllPoints();f:SetPoint('CENTER',canvas,'TOPLEFT',point.x*canvas:GetWidth(),-point.y*canvas:GetHeight());paintHandle(f)
end
local function pin()
 for _,p in ipairs(M.pins) do if not p.key then return p end end
 local p
 p=CreateFrame('Button',nil,UIParent); p:SetSize(12,12); p.icon=p:CreateTexture(nil,'ARTWORK'); p.icon:SetAllPoints(); p.outline=p:CreateTexture(nil,'OVERLAY'); p.outline:SetPoint('CENTER',p,'CENTER',0,0); p.outline:Hide()
 p.background=p:CreateTexture(nil,'BACKGROUND');p.background:SetTexture('Interface\\Minimap\\UI-Minimap-Background');p.background:SetPoint('CENTER',p,'CENTER',0,0);p.background:Hide()
 p.number=p:CreateFontString(nil,'OVERLAY');p.number:SetPoint('CENTER',p,'CENTER',0,0);p.number:SetTextColor(1,.9,.6);p.number:SetJustifyH('CENTER');p.number:SetJustifyV('MIDDLE');p.number:SetWordWrap(false);p.number:Hide()
 p:SetScript('OnEnter',function(self)
  self.hovered=true;if self.editorHandle then paintHandle(self) end
  if not GameTooltip then return end
  GameTooltip:SetOwner(self,'ANCHOR_RIGHT'); GameTooltip:SetText(self.label or 'Waypoint',1,1,1)
  if self.node then
   local skills,context=A.Resources.Skills()
   local details=A.Resources.SkillDetails(self.node,skills,context)
   GameTooltip:AddDoubleLine(self.node.kind=='herb' and 'Herbalism' or 'Mining',string.format('%.1f, %.1f',self.node.x*100,self.node.y*100),.65,.65,.65,.65,.65,.65)
   GameTooltip:AddDoubleLine(details.requirement,details.summary,.75,.75,.75,unpack(details.color))
   if details.transition then GameTooltip:AddLine(details.transition,unpack(A.Resources.colors[details.nextKey])) end
   if details.contextNote then GameTooltip:AddLine(details.contextNote,.65,.65,.65,true) end
   if self.node.confirmed then GameTooltip:AddLine('Personally gathered: '..(self.node.count or 0),.8,.9,.9) end
   if self.node.imported then GameTooltip:AddLine('From GatherMate2',.65,.65,.65) end
   if self.node.lastGathered and date then GameTooltip:AddLine('Last gathered: '..date('%d %b %H:%M',self.node.lastGathered),.8,.8,.8) end
   GameTooltip:AddLine(details.source=='reference' and 'Source: Reference data (Classic)' or 'Source: Unknown',.55,.55,.55)
  elseif self.index and not self.mini then GameTooltip:AddLine('Drag this circle to move the waypoint.',.8,.9,.9);GameTooltip:AddLine('Changes affect your draft until you save.',.7,.7,.7) end
  GameTooltip:Show()
 end)
 p:SetScript('OnLeave',function(self) self.hovered=false;if self.editorHandle then paintHandle(self) end;hideTooltip(self) end)
 p:SetScript('OnHide',function(self) if self==M.dragFrame then M.CancelDrag() end;self.hovered=false;hideTooltip(self) end)
 p:RegisterForDrag('LeftButton')
 p:RegisterForClicks('LeftButtonUp')
 p:SetScript('OnMouseDown',function(self,key) if key=='LeftButton' then self.wasDragged=false end end)
 p:SetScript('OnClick',function(self)
  if not self.mini and M.editor and self.index and not self.wasDragged then A.editIndex=self.index;if A.db then M.Refresh(A.db,M.editor.draft,nil) end;if A.UI then A.UI.Refresh() end end
 end)
 p:SetScript('OnDragStart',function(self) if self.editorHandle then M.StartDrag(self) end end)
 p:SetScript('OnDragStop',function() if M.dragIndex then M.EndDrag() end end)
 M.pins[#M.pins+1]=p; return p
end
function M.Refresh(db,route,follower)
 if not CreateFrame then return end
 hide(M.worldLines);hide(M.worldShadows); hide(M.miniLines); M.targetIndex=nil
 local lib=pinsLib()
 for _,p in ipairs(M.pins) do p.wanted=false end
 local function retire()
  for _,p in ipairs(M.pins) do
   if p.key and not p.wanted and p~=M.dragFrame then
    if lib and not p.editorHandle then if p.mini then lib:RemoveMinimapIcon(M,p) else lib:RemoveWorldMapIcon(M,p) end end
    M.byKey[p.key]=nil; p.key=nil; p.signature=nil;p:Hide();if p.editorHandle then p:SetParent(UIParent);p.editorHandle=nil end
   end
  end
 end
 local player=A.Client.Position(); local map=WorldMapFrame; local canvas=map and map:GetCanvas()
 local worldLayer=M.WorldRouteLayer(canvas)
 if M.editLayer then
  if M.editor and map:IsShown() and map:GetMapID()==M.editor.draft.mapID then M.editLayer:Show() else M.editLayer:Hide() end
 end
 M.UpdateEditorHelp()
 local zone=route and route.mapID or player and player.mapID
 local settings=A.Resources.Settings(db.settings);local skills,skillContext=A.Resources.Skills()
 local filter={source='combined'}
 local worldZone=map and map:IsShown() and map:GetMapID() or zone
 local focus=map and map:IsShown() and M.nodeFocus and M.nodeFocus.mapID==worldZone and M.nodeFocus or nil
 local worldFilter=focus and {source=focus.source,materials=focus.materials} or filter
 local nodes=(settings.world or focus) and A.Store.Select(db,worldZone,worldFilter) or {}
 local knownMiniNodes=A.Store.Select(db,player and player.mapID,filter)
 local miniNodes=settings.mini and knownMiniNodes or {}
 local distances={}
 for _,node in ipairs(miniNodes) do distances[node.key]=A.Client.Distance(player,node) end
 table.sort(miniNodes,function(a,b)
  local da,db=distances[a.key] or math.huge,distances[b.key] or math.huge
  if da==db then return a.key<b.key end; return da<db
 end)
 local function add(p,index,node,mini)
  local editing=index and not node and not mini and M.editLayer
  if not lib and not editing then return end
  local key=(mini and 'm:' or 'w:')..(node and ('node:'..node.key) or ('point:'..index))
  local f=M.byKey[key] or pin(); M.byKey[key]=f; f.key=key; f.wanted=true; f.mini=mini
  f.index=index; f.node=node; f.label=index and ('Waypoint '..index) or node and node.name
  f.icon:ClearAllPoints(); f.icon:SetPoint('CENTER',f,'CENTER',0,0)
  f.editorHandle=not not editing
  if editing then
   f:SetParent(M.editLayer);f.icon:SetTexture('Interface\\AddOns\\GatherCompassForever\\Media\\NodeRing');f.outline:Hide();f.icon:Show();f:EnableMouse(true)
   positionHandle(f);f:Show();return
  end
  f.background:Hide();f.number:Hide()
  if node then
   local style=A.Resources.Presentation(node,db.settings,mini,mini and distances[node.key],skills,skillContext)
   f.difficultyLabel=style.label
   local iconSize=style.iconSize+(not mini and focus and focus.nodeKey==node.key and 6 or 0)
   local size=style.outline=='none' and iconSize or math.max(style.outlineSize,iconSize)
   f:SetSize(size,size);f.icon:SetSize(iconSize,iconSize)
   f.icon:SetTexture(style.texture); f.icon:SetVertexColor(1,1,1)
   if style.icon then f.icon:Show() else f.icon:Hide() end
   f.outline:SetSize(style.outlineSize,style.outlineSize); f.outline:SetVertexColor(unpack(style.color))
   if style.outline~='none' then
    f.outline:SetTexture('Interface\\AddOns\\GatherCompassForever\\Media\\'..(style.outline=='ring' and 'NodeRing' or 'NodeSquare')); f.outline:Show()
   else f.outline:Hide() end
  elseif mini then
   -- Keep the native tracking dot at the destination visible too.
   f.difficultyLabel=nil; f.icon:Hide(); f.outline:SetSize(22,22)
   f.outline:SetTexture('Interface\\AddOns\\GatherCompassForever\\Media\\NodeRing')
   f.outline:SetVertexColor(1,.78,.22); f.outline:Show(); f:SetSize(22,22)
  else
   f.difficultyLabel=nil; f.outline:Hide(); f.icon:SetTexture('Interface\\TargetingFrame\\UI-RaidTargetingIcon_4')
   f.icon:SetVertexColor(1,.8,.2); f.icon:SetSize(15,15); f.icon:Show(); f:SetSize(15,15)
  end
  f:EnableMouse(not mini)
  if mini and node then
   -- Motion-only input shows node details without intercepting minimap clicks.
   if f.EnableMouseMotion then f:EnableMouseMotion(true) else f:EnableMouse(true) end
  end
  local signature=p.mapID..':'..p.x..':'..p.y
  if f~=M.dragFrame and signature~=f.signature then
   if mini then lib:AddMinimapIconMap(M,f,p.mapID,p.x,p.y,false,false)
   else
    -- HBD acquires a new world wrapper on each Add call. Retire the old
    -- wrapper when coordinates change; pure visual changes need no Add.
    if f.signature then lib:RemoveWorldMapIcon(M,f) end
    lib:AddWorldMapIconMap(M,f,p.mapID,p.x,p.y,0)
   end
   f.signature=signature
  end
  if not mini then
   -- HBD reparents to a canvas pin when the map opens. An absolute level can
   -- drop below that raised canvas on the next refresh and hide the icon.
   local parent=f:GetParent();if parent then f:SetFrameLevel(math.max(parent:GetFrameLevel()+1,worldLayer and worldLayer:GetFrameLevel()+1 or 0)) end
  end
 end
 local selected
 if focus and focus.nodeKey then for _,node in ipairs(nodes) do if node.key==focus.nodeKey then selected=node;break end end end
 if selected then add(selected,nil,selected,false) end
 local worldCount=selected and 1 or 0
 for _,node in ipairs(nodes) do
  if worldCount>=400 then break end
  if node~=selected then add(node,nil,node,false);worldCount=worldCount+1 end
 end
 for i=1,math.min(#miniNodes,400) do add(miniNodes[i],nil,miniNodes[i],true) end
 M.RaiseEditor()
 M.limited=#nodes>400 or #miniNodes>400
 if not route or #route.points==0 then retire(); return end
 local snapshot=follower and follower:Snapshot()
 local active=snapshot and (snapshot.status=='running' or snapshot.status=='paused' or snapshot.status=='suspended')
 M.targetIndex=active and snapshot.index or nil
 local points=route.points; local w,h=A.Client.Size(route.mapID)
 local preview=not M.editor and A.mapPreviewRoute or nil
 local differentPreview=preview and preview~=route
 local world=canvas and map:IsShown() and map:GetMapID()==route.mapID and not differentPreview and not focus
 local radius=C_Minimap and C_Minimap.GetViewRadius and A.Client.Read(C_Minimap.GetViewRadius())
 local facing=0
 if GetCVar and GetCVar('rotateMinimap')=='1' then facing=A.Client.Facing() end
 -- Library/editor previews belong to the world map; minimap paths require navigation.
 local mini=active and player and player.mapID==route.mapID and w and A.Store.Number(radius) and radius>0 and facing~=nil and Minimap and Minimap:IsShown()
 local holes={}
 if mini and settings.routeLines then
  holes[1]={x=0,y=0,r=8} -- Native player arrow.
  local mw,mh=Minimap:GetWidth(),Minimap:GetHeight()
  local function protect(p)
   local x,y=miniRaw(p,player,w,h,radius,mw,mh,facing)
   if math.abs(x)<=mw/2+8 and math.abs(y)<=mh/2+8 then holes[#holes+1]={x=x,y=y,r=7} end
  end
  -- Protection is independent of marker toggles and the 400-pin display cap.
  for _,node in ipairs(knownMiniNodes) do protect(node) end
  if snapshot and snapshot.target then protect(snapshot.target) end
 end
 local wi,mi=0,0
 local function drawWorld(index,a,b,color)
  local x1,y1=M.Project(a,canvas:GetWidth(),canvas:GetHeight());local x2,y2=M.Project(b,canvas:GetWidth(),canvas:GetHeight())
  local width=math.max(3,color[5] or 2)
  line(M.worldShadows,index,worldLayer,x1,y1,x2,y2,{.04,.035,.02,.7,width+2},false,'BACKGROUND')
  line(M.worldLines,index,worldLayer,x1,y1,x2,y2,{color[1],color[2],color[3],color==done and .75 or 1,width})
  local stroke=M.worldLines[index];stroke.fromPoint=a;stroke.toPoint=b;stroke.shadow=M.worldShadows[index]
 end
 local function segment(a,b,color)
  if world and wi<600 then wi=wi+1;drawWorld(wi,a,b,color) end
  if mini and settings.routeLines and mi<200 then
   local mw,mh=Minimap:GetWidth(),Minimap:GetHeight()
   local x1,y1=miniRaw(a,player,w,h,radius,mw,mh,facing); local x2,y2=miniRaw(b,player,w,h,radius,mw,mh,facing)
   x1,y1,x2,y2=M.Clip(x1,y1,x2,y2,mw,mh)
   if x1 then
    local thickness=color==gold and 1.5 or 1
    local miniColor={color[1],color[2],color[3],math.min(color[4] or 1,.55),thickness}
    for _,piece in ipairs(M.GapSegments(x1,y1,x2,y2,holes,thickness/2)) do
     if mi>=200 then break end
     mi=mi+1; line(M.miniLines,mi,Minimap,piece[1],piece[2],piece[3],piece[4],miniColor,true)
    end
   end
  end
 end
 if snapshot and snapshot.status=='running' and player and player.mapID==route.mapID then segment(player,snapshot.target,gold) end
 local stride=math.max(1,math.ceil(#points/550))
 for i=1,#points-1,stride do
  local j=math.min(i+stride,#points);local color=snapshot and snapshot.visited[i] and snapshot.visited[j] and done or teal
  if M.editor and route==M.editor.draft and A.editIndex and A.editIndex>i and A.editIndex<j then segment(points[i],points[A.editIndex],color);segment(points[A.editIndex],points[j],color)
  else segment(points[i],points[j],color) end
 end
 if route.loop and #points>1 then segment(points[#points],points[1],teal) end
 -- Numbered world-map handles are editing controls, not gathering markers.
 if M.editor and route==M.editor.draft and world then
  for i=1,#points,math.max(1,math.ceil(#points/200)) do add(points[i],i,nil,false) end
  if points[A.editIndex or 1] then add(points[A.editIndex or 1],A.editIndex or 1,nil,false) end
 end
 if active and snapshot.target then add(snapshot.target,snapshot.index,nil,true) end
 -- A selected-route world-map preview must not redirect the active minimap leg.
 if differentPreview and not focus and canvas and map:IsShown() and map:GetMapID()==preview.mapID then
  local pp=preview.points; local count=0; local step=math.max(1,math.ceil(#pp/550))
  local function previewLine(a,b)
   count=count+1;drawWorld(count,a,b,teal)
  end
  for i=1,#pp-1,step do previewLine(pp[i],pp[math.min(i+step,#pp)]) end
  if preview.loop and #pp>1 then previewLine(pp[#pp],pp[1]) end
 end
 retire()
 M.CollectDragLinks()
end
