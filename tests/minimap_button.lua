local function launcherSetup(saved)
 dofile('tests/wow.lua');fakeUI();local A={};module('Store',A);module('Skin',A)
 A.db=A.Store.Open(saved);local toggles=0;A.UI={Toggle=function() toggles=toggles+1 end}
 Minimap.GetCenter=function() return 300,200 end
 Minimap.GetEffectiveScale=function() return .75 end
 GetMinimapShape=function() return 'ROUND' end
 GetCursorPosition=function() return 300*.75,320*.75 end
 module('MinimapButton',A);A.MinimapButton.Build()
 return A,function() return toggles end
end

test('minimap launcher opens the panel keeps drag separate and restores the saved position',function()
 local A,toggles=launcherSetup();local b=A.MinimapButton.frame;assert(b and b:IsShown())
 eq(b:GetParent(),Minimap);eq(b.icon.texture,A.Skin.media..'EmptyEmblem')
 b.scripts.OnMouseDown(b,'LeftButton');b.scripts.OnClick(b,'LeftButton');eq(toggles(),1)
 b.scripts.OnMouseDown(b,'LeftButton');b.scripts.OnDragStart(b);assert(b.scripts.OnUpdate)
 b.scripts.OnUpdate(b);b.scripts.OnDragStop(b);b.scripts.OnClick(b,'LeftButton');eq(toggles(),1)
 near(A.db.settings.minimapAngle,90);eq(b.scripts.OnUpdate,nil)
 local saved=A.db;local B=launcherSetup(saved);near(B.db.settings.minimapAngle,90)
 local anchor;B.MinimapButton.frame.SetPoint=function(_,...) anchor={...} end;B.MinimapButton.Refresh()
 near(anchor[4],0);near(anchor[5],108)
 GetMinimapShape=function() return 'SQUARE' end;B.db.settings.minimapAngle=45;B.MinimapButton.Refresh()
 near(anchor[4],108);near(anchor[5],108)
 GetCursorPosition=nil;GetMinimapShape=nil
end)

test('minimap visibility and tooltip clean up without affecting navigation or node data',function()
 local A,toggles=launcherSetup();local b=A.MinimapButton.frame;local lines={};local shown
 GameTooltip.SetText=function(_,text) lines={text} end;GameTooltip.AddLine=function(_,text) lines[#lines+1]=text end
 GameTooltip.IsOwned=function(_,owner) return owner==b end
 GameTooltip.Show=function() shown=true end;GameTooltip.Hide=function() shown=false end
 b.scripts.OnEnter(b);assert(shown);assert(table.concat(lines,'\n'):find('Drag',1,true))
 local follower={status='running'};A.follower=follower
 A.db.settings.minimapButton=false;A.MinimapButton.Refresh();eq(b:IsShown(),false);eq(shown,false);eq(A.follower,follower)
 A.db.settings.minimapButton=true;A.MinimapButton.Refresh();eq(b:IsShown(),true)
 b.scripts.OnMouseDown(b,'RightButton');b.scripts.OnClick(b,'RightButton');eq(toggles(),0)
 A.db.settings.minimapAngle=0/0;A.MinimapButton.Refresh();assert(A.Store.Number(A.db.settings.minimapAngle))
 GetCursorPosition=nil;GetMinimapShape=nil
end)

local function collect(A)
 local b=A.MinimapButton.frame;local sink=CreateFrame('Frame',nil,UIParent)
 b:SetParent(sink);b:SetSize(24,24);b:ClearAllPoints();b:SetPoint('TOPLEFT',sink,'TOPLEFT',6,-6)
 if b.scripts.OnSizeChanged then b.scripts.OnSizeChanged(b,24,24) end
 return b,sink,b.point
end

local function eqolCollector(A)
 local b=A.MinimapButton.frame;local sink=CreateFrame('Frame','EnhanceQoL_ButtonSink',UIParent);local found=false
 local eq={db={enableMinimapButtonBin=true},variables={buttonSink=sink},functions={},scans=0}
 function eq.functions.gatherMinimapButtons()
  eq.scans=eq.scans+1
  if b:GetParent()==Minimap and b:IsVisible() and not b.db.hide then found=true end
 end
 function eq.functions.LayoutButtons()
  if found then b:SetParent(sink);b:ClearAllPoints();b:SetSize(32,32);b:SetPoint('TOPLEFT',sink,'TOPLEFT',4,-4);b:Show() end
 end
 return eq,sink
end

test('launcher uses the native minimap rim with its complete badge inside',function()
 local A=launcherSetup();local b=A.MinimapButton.frame
 assert(b.border,'Standard minimap border is missing');eq(b.border.texture,'Interface\\Minimap\\MiniMap-TrackingBorder')
 assert(b.background);assert(b.icon:GetWidth()<b:GetWidth());eq(b.icon.texture,A.Skin.media..'EmptyEmblem')
 b:SetSize(24,24);if b.scripts.OnSizeChanged then b.scripts.OnSizeChanged(b,24,24) end
 near(b.icon:GetWidth(),15);near(b.border:GetWidth(),53*24/32)
 GetCursorPosition=nil;GetMinimapShape=nil
end)

test('EQoL recollects the launcher after a scan while the minimap was hidden',function()
 local old=EnhanceQoL;local A=launcherSetup();local b=A.MinimapButton.frame;local collector,sink=eqolCollector(A);EnhanceQoL=collector
 Minimap:Hide();collector.functions.gatherMinimapButtons();collector.functions.LayoutButtons();eq(b:GetParent(),Minimap)
 Minimap:Show();eq(b:GetParent(),sink);eq(b.point[2],sink)
 local scans=collector.scans;local anchor=b.point;A.MinimapButton.Refresh();eq(collector.scans,scans);eq(b.point,anchor)
 EnhanceQoL=old;GetCursorPosition=nil;GetMinimapShape=nil
end)

test('EQoL discovers a previously hidden launcher when the Gatherly preference enables it',function()
 local old=EnhanceQoL;local A=launcherSetup();local b=A.MinimapButton.frame;local collector,sink=eqolCollector(A);EnhanceQoL=collector
 A.db.settings.minimapButton=false;A.MinimapButton.Refresh();collector.functions.gatherMinimapButtons();collector.functions.LayoutButtons()
 eq(b:GetParent(),Minimap);A.db.settings.minimapButton=true;A.MinimapButton.Refresh();eq(b:GetParent(),sink)
 EnhanceQoL=old;GetCursorPosition=nil;GetMinimapShape=nil
end)

test('EQoL ignore preferences and disabled sinks preserve standalone launcher behavior',function()
 for _,setting in ipairs({'disabled','ignored'}) do
  local old=EnhanceQoL;local A=launcherSetup();local b=A.MinimapButton.frame;local collector=eqolCollector(A);EnhanceQoL=collector
  if setting=='disabled' then collector.db.enableMinimapButtonBin=false else collector.db.ignoreMinimapButtonBin_GatherlyMinimapButton=true end
  A.MinimapButton.Refresh();eq(b:GetParent(),Minimap);eq(collector.scans,0)
  EnhanceQoL=old;GetCursorPosition=nil;GetMinimapShape=nil
 end
end)

test('a late EQoL load collects the existing launcher without reacting to unrelated addons',function()
 local old=EnhanceQoL;local A=launcherSetup();local b=A.MinimapButton.frame;local collector,sink=eqolCollector(A);EnhanceQoL=collector
 b.scripts.OnEvent(b,'ADDON_LOADED','OtherAddon');eq(collector.scans,0)
 b.scripts.OnEvent(b,'ADDON_LOADED','EnhanceQoL');eq(b:GetParent(),sink)
 EnhanceQoL=old;GetCursorPosition=nil;GetMinimapShape=nil
end)

test('a faulty collector cannot break the launcher or prevent later discovery',function()
 local old=EnhanceQoL;local A,toggles=launcherSetup();local b=A.MinimapButton.frame;local collector,sink=eqolCollector(A);EnhanceQoL=collector
 local scan=collector.functions.gatherMinimapButtons
 collector.functions.gatherMinimapButtons=function() error('Collector not ready') end
 assert(pcall(A.MinimapButton.Refresh));eq(b:GetParent(),Minimap);eq(A.MinimapButton.notifying,nil)
 b.scripts.OnClick(b,'LeftButton');eq(toggles(),1)
 collector.functions.gatherMinimapButtons=scan;A.MinimapButton.Refresh();eq(b:GetParent(),sink)
 EnhanceQoL=old;GetCursorPosition=nil;GetMinimapShape=nil
end)

test('collector placement and visibility survive minimap callbacks and repeated initialization',function()
 local A=launcherSetup();local b,sink,anchor=collect(A);b:Hide()
 A.MinimapButton.Refresh();eq(b.point,anchor);eq(b:GetParent(),sink);eq(b:IsShown(),false);eq(b:GetWidth(),24)
 Minimap.scripts.OnSizeChanged(Minimap,220,220);Minimap.scripts.OnShow(Minimap);A.MinimapButton.Build()
 eq(b.point,anchor);eq(b:GetParent(),sink);eq(b:IsShown(),false);eq(A.MinimapButton.frame,b)
 b:Show();sink:Hide();A.MinimapButton.Refresh();eq(b:IsVisible(),false);eq(sink:IsShown(),false)
 GetCursorPosition=nil;GetMinimapShape=nil
end)

test('collector drag never changes the orbit angle or opens Gatherly on release',function()
 local A,toggles=launcherSetup();local b,_,anchor=collect(A);local before=A.db.settings.minimapAngle
 b.scripts.OnMouseDown(b,'LeftButton');b.scripts.OnDragStart(b)
 if b.scripts.OnUpdate then b.scripts.OnUpdate(b) end
 b.scripts.OnDragStop(b);b.scripts.OnClick(b,'LeftButton')
 eq(A.db.settings.minimapAngle,before);eq(b.point,anchor);eq(b.scripts.OnUpdate,nil);eq(toggles(),0)
 b.scripts.OnMouseDown(b,'LeftButton');b.scripts.OnClick(b,'LeftButton');eq(toggles(),1)
 GetCursorPosition=nil;GetMinimapShape=nil
end)

test('docking interrupts an active orbit drag and returning to the minimap restores normal placement',function()
 local A=launcherSetup();local b=A.MinimapButton.frame
 b.scripts.OnDragStart(b);assert(b.scripts.OnUpdate)
 local _,_,anchor=collect(A);local angle=A.db.settings.minimapAngle
 b.scripts.OnUpdate(b);eq(b.scripts.OnUpdate,nil);eq(b.dragging,false);eq(b.point,anchor);eq(A.db.settings.minimapAngle,angle)
 b:SetParent(Minimap);A.MinimapButton.Refresh();eq(b.point[2],Minimap);eq(b:GetWidth(),32);eq(b:GetHeight(),32);eq(b:IsShown(),true)
 GetCursorPosition=nil;GetMinimapShape=nil
end)

test('Gatherly visibility preference remains authoritative inside a collector',function()
 local A=launcherSetup();local b,_,anchor=collect(A)
 A.db.settings.minimapButton=false;A.MinimapButton.Refresh();assert(b.db and b.db.hide==true);eq(b:IsShown(),false)
 b:Show();eq(b:IsShown(),false)
 A.db.settings.minimapButton=true;A.MinimapButton.Refresh();eq(b.db.hide,false);eq(b:IsShown(),true);eq(b.point,anchor)
 b:Hide();A.MinimapButton.Refresh();eq(b:IsShown(),false)
 GetCursorPosition=nil;GetMinimapShape=nil
end)

test('launcher icon follows collector size and hiding preserves foreign update handlers',function()
 local A=launcherSetup();local b=collect(A);eq(b.icon.point[2],b);eq(b.icon:GetWidth(),15);eq(b.icon:GetHeight(),15)
 local update=function() end;b:SetScript('OnUpdate',update);b:Hide();eq(b.scripts.OnUpdate,update)
 GetCursorPosition=nil;GetMinimapShape=nil
end)

test('collector takeover preserves a wrapped update handler and stops the old drag after release',function()
 local A=launcherSetup();local b=A.MinimapButton.frame;b.scripts.OnDragStart(b)
 local own=b.scripts.OnUpdate;local calls=0
 local foreign=function(self) own(self);calls=calls+1 end;b:SetScript('OnUpdate',foreign)
 collect(A);A.MinimapButton.Refresh();eq(b.scripts.OnUpdate,foreign);eq(b.dragging,false)
 local angle=A.db.settings.minimapAngle;foreign(b)
 b:SetParent(Minimap);GetCursorPosition=function() return 100,100 end;foreign(b)
 eq(calls,2);eq(A.db.settings.minimapAngle,angle)
 GetCursorPosition=nil;GetMinimapShape=nil
end)
