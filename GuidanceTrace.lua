local _,A=...
local D={active=false};A.GuidanceTrace=D
local S=A.Store
local function clean(value)
 value=A.Client.Read(value)
 return type(value)=='string' and value:gsub('[%c|]',' '):sub(1,180) or nil
end
local function point(p) if S.Position(p) then return {mapID=p.mapID,x=p.x,y=p.y} end end
local function saved()
 local data=A.db and A.db.guidanceTrace
 if type(data)=='table' and data.version==1 and type(data.events)=='table' then return data end
end
local function message(s) if A.Print then A.Print(s) end end
function D.Start()
 if not A.db then return end
 local build
 if type(GetBuildInfo)=='function' then local ok,_,v=pcall(GetBuildInfo);if ok then build=clean(v) end end
 A.db.guidanceTrace={version=1,addonVersion=A.version or '1.0.1',clientBuild=build,terrainBuild=A.TerrainData and A.TerrainData.build,events={}}
 D.active=true;D.previous=nil;D.lastPosition=nil;D.started=nil
 if D.frame then D.frame:Hide() end
 message('Guidance trace started. Follow your route; after the arrow disappears and recovers, use /gatherly trace report.')
end
function D.Stop(silent)
 D.active=false;D.previous=nil
 if not silent then message('Guidance trace stopped. /gatherly trace report shows the saved history.') end
end
function D.Sample(f,p,positionReason,now,arrowIssue)
 if not D.active then return end
 local data=saved();if not data then return end
 local previous=D.previous
 if not f and not previous then return end
 if S.Position(p) then D.lastPosition=point(p) end
 local status=f and f.status or 'stopped'
 arrowIssue=status=='running' and clean(arrowIssue) or nil
 local cause=arrowIssue or clean(f and f.failureCode) or (status=='suspended' and 'connection-unavailable' or nil)
 local readReason=not S.Position(p) and clean(positionReason) or nil
 local runID=f and f.runID
 local event
 if not previous or previous.runID~=runID then event=f and 'following' or 'stopped'
 elseif status=='suspended' and (previous.status~=status or previous.cause~=cause or previous.positionReason~=readReason) then event='dropout'
 elseif previous.status=='suspended' and status=='running' then event='recovered'
 elseif previous.status=='paused' and status=='running' then event='resumed'
 elseif status=='running' and previous.arrowIssue~=arrowIssue then event=arrowIssue and 'arrow-unavailable' or 'arrow-restored'
 elseif previous.direction~=(f and f.direction) and status=='running' then event='direction-changed'
 elseif previous.status~=status then event=status end
 D.previous={status=status,cause=cause,positionReason=readReason,runID=runID,direction=f and f.direction,arrowIssue=arrowIssue}
 if not event then return end
 now=S.Number(now) and now or 0;D.started=D.started or now
 local target=f and f:Target() or nil
 local route=f and f.route
 local e={event=event,time=math.max(0,now-D.started),cause=cause,reason=clean(f and f.reason),positionReason=readReason,
  runID=runID,mapID=route and route.mapID,index=f and f.index,total=route and #route.points,direction=f and f.direction,lap=f and f.lap,
  position=point(p),lastPosition=point(D.lastPosition),target=point(target or route and route.points[f.index])}
 if A.Terrain and S.Position(p) then
  local z=A.Terrain.Zone(p.mapID)
  if z then e.cellX=math.min(z.w-1,math.floor(p.x*z.w));e.cellY=math.min(z.h-1,math.floor(p.y*z.h));e.allowed=A.Terrain.Allowed(p) end
 end
 data.events[#data.events+1]=e
 if #data.events>40 then table.remove(data.events,1) end
end
local function number(n) return S.Number(n) and tostring(n) or '?' end
local function coordinates(p)
 if not S.Position(p) then return '?' end
 return string.format('%s:%.2f,%.2f',p.mapID,p.x*100,p.y*100)
end
function D.Text()
 local data=saved()
 if not data or #data.events==0 then return 'No guidance trace saved. Use /gatherly trace, then follow a route.' end
 local lines={'Gatherly guidance trace v1 | addon '..(clean(data.addonVersion) or '?')..' | client build '..(clean(data.clientBuild) or '?')..' | terrain build '..number(data.terrainBuild)}
 for i=1,math.min(40,#data.events) do
  local e=data.events[i]
  if type(e)=='table' then
   lines[#lines+1]=string.format('+%.1fs %s: %s%s',S.Number(e.time) and e.time or 0,clean(e.event) or '?',clean(e.cause) or 'ok',e.positionReason and (' / '..(clean(e.positionReason) or '?')) or '')
   lines[#lines+1]='  route map '..number(e.mapID)..', waypoint '..number(e.index)..'/'..number(e.total)..', direction '..number(e.direction)..', lap '..number(e.lap)
   lines[#lines+1]='  position '..coordinates(e.position)..'; last readable '..coordinates(e.lastPosition)..'; target '..coordinates(e.target)
   if e.cellX then lines[#lines+1]='  mask cell '..number(e.cellX)..','..number(e.cellY)..' permitted='..tostring(e.allowed==true) end
   if e.reason then lines[#lines+1]='  '..(clean(e.reason) or '?') end
  end
 end
 return table.concat(lines,'\n')
end
function D.Report()
 D.Stop(true);local text=D.Text()
 if not CreateFrame or not A.Skin or not A.ScrollPanel then message(text);return text end
 local f=D.frame
 if not f then
  f=CreateFrame('Frame','GatherlyTraceReport',UIParent,'BackdropTemplate');D.frame=f
  f:SetPoint('CENTER');f:SetFrameStrata('DIALOG');f:SetClampedToScreen(true)
  f:SetFrameLevel((A.UI and A.UI.frame and A.UI.frame:GetFrameLevel() or 1)+100)
  f:SetBackdrop({bgFile='Interface\\DialogFrame\\UI-DialogBox-Background',edgeFile='Interface\\DialogFrame\\UI-DialogBox-Border',tile=true,tileSize=32,edgeSize=24,insets={left=6,right=6,top=6,bottom=6}})
  f.title=A.Skin.Label(f,'Guidance diagnostic report',16,A.Skin.gold);f.title:SetPoint('TOPLEFT',f,'TOPLEFT',18,-14);f.title:SetSize(430,24)
  f.hint=A.Skin.Label(f,'Press Ctrl+A, then Ctrl+C to copy this report. Recording is stopped.',12,A.Skin.text);f.hint:SetPoint('TOPLEFT',f,'TOPLEFT',18,-46)
  f.close=A.Skin.Button(f,'Close',function() f:Hide() end);f.close:SetPoint('TOPRIGHT',f,'TOPRIGHT',-14,-12);f.close:SetSize(70,24)
  f.scroll=A.ScrollPanel.New(f);f.scroll.frame:SetPoint('TOPLEFT',f,'TOPLEFT',18,-76)
  f.edit=CreateFrame('EditBox',nil,f.scroll.body);f.edit:SetPoint('TOPLEFT',f.scroll.body,'TOPLEFT',4,-4);f.edit:SetMultiLine(true);f.edit:SetAutoFocus(false)
  f.edit:SetFontObject(ChatFontNormal);f.edit:SetJustifyH('LEFT');f.edit:SetJustifyV('TOP');f.edit:SetMaxLetters(24000);f.edit:SetScript('OnEscapePressed',function() f:Hide() end)
  f:SetScript('OnHide',function() f.edit:ClearFocus() end)
  if UISpecialFrames then UISpecialFrames[#UISpecialFrames+1]='GatherlyTraceReport' end
 end
 local w,h=math.min(720,UIParent:GetWidth()-24),math.min(500,UIParent:GetHeight()-24)
 f:SetSize(w,h);f.hint:SetSize(w-36,26)
 local _,lines=text:gsub('\n','');local height=math.max(h-100,(lines+1)*28)
 local width=f.scroll:Layout(w-36,h-94,height)
 f.edit:SetSize(width-8,height);f.edit:SetText(text);f:Show();f.edit:SetFocus();f.edit:HighlightText();f.scroll:SetOffset(0)
 message('Guidance report ready to copy. Use /gatherly trace to record another incident.')
 return text
end
