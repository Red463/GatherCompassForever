local _, A = ...
local R={}; A.Arrow=R
local atan2=math.atan2 or function(y,x) return math.atan(y/x)+(x<0 and (y>=0 and math.pi or -math.pi) or 0) end
function R.Angle(target,player,w,h,facing)
 return atan2(-(target.x-player.x)*w,-(target.y-player.y)*h)-facing
end
local nameTarget,nameKey,nameNodes,linkedNode
function R.TargetName(target)
 if type(target)~='table' then return nil end
 if type(target.name)=='string' and target.name~='Farming corridor' and target.name:find('%S') then return target.name end
 local nodes=A.db and A.db.nodes and A.db.nodes[target.mapID]
 if nameTarget~=target or nameKey~=target.nodeKey or nameNodes~=nodes then
  nameTarget,nameKey,nameNodes,linkedNode=target,target.nodeKey,nodes,nil
  if type(target.nodeKey)=='string' and type(nodes)=='table' then
   for _,node in ipairs(nodes) do if node.key==target.nodeKey then linkedNode=node;break end end
  end
 end
 if linkedNode and type(linkedNode.name)=='string' and linkedNode.name:find('%S') then return linkedNode.name end
 return target.kind=='gather' and 'Gathering stop' or 'Travel waypoint'
end
local function layout(frame)
 local named=frame.nodeName:IsShown()
 frame.progress:ClearAllPoints();frame.progress:SetPoint('TOP',frame,'TOP',0,named and -106 or -86)
 local height=84+(named and 20 or 0)+(frame.progress:IsShown() and 20 or 0)
 if frame.zoomHint then frame.zoomHint:ClearAllPoints();frame.zoomHint:SetPoint('TOP',frame,'TOP',0,-height-2) end
 frame:SetHeight(height+(frame.zoomHint and frame.zoomHint:IsShown() and 20 or 0))
end
local tau=2*math.pi
local function normalize(angle) return (angle+math.pi)%tau-math.pi end
function R.SmoothAngle(current,target,elapsed)
 if not A.Store.Number(current) then return target end
 if not A.Store.Number(target) or not A.Store.Number(elapsed) or elapsed<=0 then return current end
 local difference=normalize(target-current)
 return normalize(current+difference*(1-math.exp(-18*elapsed)))
end
local function rotate(frame,angle)
 frame.renderAngle=angle;frame.icon:SetRotation(angle);frame.shadow:SetRotation(angle)
end
function R.Animate(elapsed)
 local f=R.frame
 if not f or not f:IsShown() or not A.Store.Number(f.bearing) then return end
 local facing=A.Client.Facing();if not A.Store.Number(facing) then return end
 local angle=R.SmoothAngle(f.renderAngle,f.bearing-facing,elapsed)
 if angle~=f.renderAngle then rotate(f,angle) end
end
function R.Build()
 if R.frame or not CreateFrame then return end
 local f=CreateFrame('Frame','GatherlyArrow',UIParent); R.frame=f
 f:SetSize(156,84); f:SetPoint('CENTER',UIParent,'CENTER',0,140); f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag('LeftButton'); f:SetClampedToScreen(true)
 f:SetFrameStrata('DIALOG')
 f:SetScript('OnMouseDown',function(self,button) if button=='LeftButton' then self.wasDragged=false end end)
 f:SetScript('OnMouseUp',function(self,button) if button=='LeftButton' and not self.wasDragged and A.UI then A.UI.OpenRoutes() end end)
 f:SetScript('OnDragStart',function(self) self.wasDragged=true; self:StartMoving() end)
 f:SetScript('OnDragStop',function(self)
  self:StopMovingOrSizing(); if not A.db then return end
  local p,_,rp,x,y=self:GetPoint(); A.db.settings.arrowAnchor={p,rp,x,y}
 end)
 local saved=A.db and A.db.settings.arrowAnchor
 if type(saved)=='table' and type(saved[1])=='string' and A.Store.Number(saved[3]) and A.Store.Number(saved[4]) then
  f:ClearAllPoints(); f:SetPoint(saved[1],UIParent,saved[2],saved[3],saved[4])
 end
 f.shadow=f:CreateTexture(nil,'ARTWORK',nil,0);f.shadow:SetTexture(A.Skin.media..'GuideArrow');f.shadow:SetSize(56,56);f.shadow:SetVertexColor(0,0,0,.7)
 local tex=f:CreateTexture(nil,'ARTWORK',nil,1);f.icon=tex;tex:SetTexture(A.Skin.media..'GuideArrow');tex:SetSize(56,56);tex:SetPoint('TOP',f,'TOP',0,-2);tex:SetVertexColor(1,1,1,1)
 f.shadow:SetPoint('CENTER',tex,'CENTER',2,-2)
 f.stateGlyph=A.Skin.Label(f,'',30,A.Skin.muted);f.stateGlyph:SetPoint('TOP',f,'TOP',0,-2);f.stateGlyph:SetSize(56,56);f.stateGlyph:SetJustifyH('CENTER');f.stateGlyph:Hide()
 f.label=A.Skin.Label(f,'',20,A.Skin.gold);f.label:SetPoint('TOP',f,'TOP',0,-60);f.label:SetSize(148,24);f.label:SetJustifyH('CENTER')
 f.nodeName=A.Skin.Label(f,'',12,A.Skin.text);f.nodeName:SetPoint('TOP',f,'TOP',0,-86);f.nodeName:SetSize(148,18);f.nodeName:SetJustifyH('CENTER');f.nodeName:Hide()
 f.progress=A.Skin.Label(f,'',11,A.Skin.muted);f.progress:SetPoint('TOP',f,'TOP',0,-86);f.progress:SetSize(148,16);f.progress:SetJustifyH('CENTER');f.progress:Hide()
 f.zoomHint=A.Skin.Label(f,'Zoom minimap fully out',11,A.Skin.gold);f.zoomHint:SetSize(148,16);f.zoomHint:SetJustifyH('CENTER');f.zoomHint:Hide()
 A.Skin.Hint(f,'Gatherly',R.TooltipText)
 f:SetScript('OnUpdate',function(_,elapsed) R.Animate(elapsed) end)
 f:SetScript('OnHide',function(self)
  self.bearing=nil;self.renderAngle=nil
  if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(self) then GameTooltip:Hide() end
 end)
 f:Hide()
end
function R.TooltipText()
 local f=R.frame; local lines={}
 if f and f.destination then lines[#lines+1]=tostring(f.destination):gsub('|','||') end
 if f and f.progress and f.progress:GetText()~='' then lines[#lines+1]=f.progress:GetText() end
 if f and f.stateReason then lines[#lines+1]=f.stateReason end
 if f and f.coverageRadius then
  lines[#lines+1]=string.format('Known locations within %.0f yards of the route are covered.',f.coverageRadius)
  lines[#lines+1]='Designed for a fully zoomed-out minimap.'
  if f.rangeReduced then lines[#lines+1]='Current minimap range is smaller than the saved coverage. Regenerate to use the current view.' end
 end
 lines[#lines+1]='';lines[#lines+1]='Left-click to open routes. Drag to move the guide.'
 return table.concat(lines,'\n')
end
function R.UpdateName(target)
 R.Build();local f=R.frame;if not f then return end
 f.destination=R.TargetName(target)
 local enabled=A.db and A.db.settings and A.db.settings.arrowNodeName==true
 if enabled and f.destination then f.nodeName:SetText(f.destination:gsub('|','||'));f.nodeName:Show()
 else f.nodeName:SetText('');f.nodeName:Hide() end
 layout(f)
end
function R.UpdateProgress(snapshot)
 R.Build(); local f=R.frame; if not f then return end
 local text
 local enabled=not (A.db and A.db.settings and A.db.settings.arrowProgress==false)
 if enabled and snapshot and A.Store.Number(snapshot.index) and A.Store.Number(snapshot.total) and snapshot.index>=1 and snapshot.index<=snapshot.total then
  text=string.format('%d/%d',snapshot.index,snapshot.total)
  if snapshot.loop then
   local lap=A.Store.Number(snapshot.lap) and math.max(0,snapshot.lap) or 0
   text=text..string.format(' - Lap %d',lap+1)
  end
 end
 f.progress:SetText(text or '')
 if text then f.progress:Show() else f.progress:Hide() end
 layout(f)
end
function R.UpdateZoom(snapshot)
 local f=R.frame;if not f then return end
 f.coverageRadius=snapshot and snapshot.corridor and A.Store.Number(snapshot.coverageRadius) and snapshot.coverageRadius or nil
 local zoom=f.coverageRadius and A.Client.MinimapZoom and A.Client.MinimapZoom()
 local radius=f.coverageRadius and A.Client.MinimapRadius and A.Client.MinimapRadius()
 f.rangeReduced=A.Store.Number(radius) and radius>0 and radius<f.coverageRadius or false
 if zoom and zoom>0 then f.zoomHint:SetText('Zoom minimap fully out');f.zoomHint:Show()
 elseif f.rangeReduced then f.zoomHint:SetText('Minimap range reduced');f.zoomHint:Show()
 else f.zoomHint:Hide() end
 layout(f)
end
function R.Update(position,facing,target,distance,snapshot)
 R.Build(); local f=R.frame; if not f then return end
 local d=target and distance(position,target); local w,h
 if position then w,h=A.Client.Size(position.mapID) end
 if not target or snapshot and (snapshot.status=='complete' or snapshot.status=='stopped') then R.UpdateName(nil);R.UpdateZoom(nil);f:Hide();return end
 R.UpdateName(snapshot and snapshot.nameTarget or target);R.UpdateProgress(snapshot);R.UpdateZoom(snapshot)
 f:SetScale(math.max(.6,math.min(2,tonumber(A.db and A.db.settings.arrowScale) or 1)))
 local paused=snapshot and snapshot.status=='paused'
 local valid=A.Store.Number(d) and A.Store.Number(facing) and w and position
 if paused or not valid then
  f.bearing=nil;f.renderAngle=nil
  f.icon:Hide();f.shadow:Hide();f.stateGlyph:SetText(paused and 'II' or '?');f.stateGlyph:Show()
  f.label:SetText(paused and 'Paused' or 'No direction')
  f.stateReason=paused and 'Paused. Open routes to resume.' or (snapshot and snapshot.reason or 'Position or facing unavailable.')
 else
  -- Position/target geometry stays on the normal route tick. The visible HUD
  -- samples only facing each frame and blends rotation independently.
  f.bearing=R.Angle(target,position,w,h,0)
  f.stateGlyph:Hide();f.icon:Show();f.shadow:Show()
  if f.renderAngle==nil then rotate(f,normalize(f.bearing-facing)) end
  f.label:SetText(string.format('%d yd',d+.5));f.stateReason=nil
 end
 f:Show()
 if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(f) then
  GameTooltip:ClearLines();GameTooltip:SetText('Gatherly');GameTooltip:AddLine(R.TooltipText(),.8,.8,.72,true);GameTooltip:Show()
 end
end
