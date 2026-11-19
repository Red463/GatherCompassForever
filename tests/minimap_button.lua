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
 eq(b:GetParent(),Minimap);eq(b.icon.texture,A.Skin.media..'Icon')
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
