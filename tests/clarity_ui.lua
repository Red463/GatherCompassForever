local function setup()
 dofile('tests/wow.lua');fakeUI();local A={};for _,m in ipairs({'Store','Client','Planner','Follower'}) do module(m,A) end;moduleUI(A)
 A.version='0.13.0';A.db=A.Store.Open();A.Client.Position=function() return point(.3) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance;A.Client.Probe=function() return {loot=true,facing=true,distance=true,minimap=true} end
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end
test('Preferences explains waypoint radius live and groups resets with their own settings',function()
 local A,U=setup();U.SetTab('settings');assert(U.preferencesView);local v=U.preferencesView
 assert(v.arrivalLabel:GetText():find('Advance to next waypoint',1,true));assert(v.arrivalHelp:GetText():find('15 yards',1,true));assert(v.arrivalHelp:GetText():find('gather',1,true))
 U.controls.arrival.scripts.OnValueChanged(U.controls.arrival,25);assert(v.arrivalHelp:GetText():find('25 yards',1,true))
 eq(U.controls.resetArrow:GetParent(),v.arrow);eq(U.controls.resetPanel:GetParent(),v.panel)
 U.window:SetPreset('small');assert(v.scroller.maximum>0);eq(U.controls.arrival:GetHeight(),18)
end)
test('expanded title uses runtime version and portrait is centred on the native container',function()
 local A,U=setup();eq(U.chrome.title,'Gatherly v0.13.0')
 local create=CreateFrame;local native
 CreateFrame=function(kind,name,parent,template) local f=create(kind,name,parent,template);if template=='PortraitFrameTemplate' then f.PortraitContainer=create('Frame',nil,f);f.PortraitContainer.portrait=create('Texture',nil,f.PortraitContainer);native=f end;return f end
 local chrome=A.Skin.Window(UIParent);eq(chrome.brandPortrait.point[1],'CENTER');eq(chrome.brandPortrait.point[2],native.PortraitContainer);eq(chrome.brandPortrait.point[3],'TOPLEFT');eq(chrome.brandPortrait.point[4],26);eq(chrome.brandPortrait.point[5],-24)
 eq(chrome.brandPortrait.texture,A.Skin.media..'EmptyEmblem')
 local uv=chrome.brandPortrait.coords;eq(uv[1],0);eq(uv[2],1);eq(uv[3],0);eq(uv[4],1)
 eq(chrome.brandPortrait:GetWidth(),58);eq(chrome.brandPortrait:GetHeight(),58)
end)
test('map-marker preview includes a map-backed labelled appearance example',function()
 local A,U=setup();U.SetTab('nodes');U.nodeDisplayView.SetPage('world');local v=U.nodeDisplayView
 assert(v.previewArt and v.previewCanvas);eq(v.previewCaption:GetText(),'Appearance example')
 eq(v.worldExamples[1].texture,A.Resources.Icon({kind='herb',materialID='gm:herb:402'}));eq(v.miniIcon.texture,A.Resources.Icon({kind='herb',materialID='gm:herb:402'}))
 A.Resources.Settings(A.db.settings).groupWorld=false;U.Refresh();eq(v.worldCount:IsShown(),false)
 A.Resources.Settings(A.db.settings).worldIconOpacity=.3;U.Refresh();near(v.worldExamples[1].alpha,.3)
end)
test('minimap launcher shows the complete badge without a second border or clipping mask',function()
 local A=setup();module('MinimapButton',A);A.MinimapButton.Build();local b=A.MinimapButton.frame
 eq(b.icon.texture,A.Skin.media..'EmptyEmblem');eq(b.icon.point[1],'CENTER');eq(b.icon.point[4],0);eq(b.icon.point[5],0)
 local uv=b.icon.coords;eq(uv[1],0);eq(uv[2],1);eq(uv[3],0);eq(uv[4],1)
 eq(b.icon:GetWidth(),32);eq(b.icon:GetHeight(),32);eq(b.border,nil);eq(b.mask,nil);eq(b.icon.masks,nil)
end)
