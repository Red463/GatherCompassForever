local function setup(saved)
 dofile('tests/wow.lua');fakeUI();local A={};for _,name in ipairs({'Store','Client','Editor','Follower'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open(saved);A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.UI.Build();return A,A.UI
end
test('first opening shows Welcome once and preserves normal routes navigation afterward',function()
 local A,U=setup();eq(U.tab,'welcome');eq(A.db.settings.welcomeSeen,nil)
 U.Toggle();eq(U.welcomeView.frame:IsVisible(),true);eq(U.sidebar:IsShown(),false);eq(U.content:GetWidth(),936);eq(A.db.settings.welcomeSeen,true)
 U.OpenRoutes();U.Toggle();U.Toggle();eq(U.tab,'routes')
 local B,V=setup(A.Store.Copy(A.db));eq(V.tab,'routes');V.Toggle();eq(V.sidebar:IsVisible(),true)
end)
test('only Welcome has an import button and other pages provide navigation instead',function()
 local A,U=setup();U.Toggle();assert(U.controls.import:IsVisible());eq(U.controls.emptyImport,nil);eq(U.controls.resourceImport,nil)
 eq(U.controls.import:GetParent(),U.welcomeView.cards[1])
 for _,tab in ipairs({'routes','atlas','resources','nodes','settings'}) do U.SetTab(tab);eq(U.controls.import:IsVisible(),false) end
 U.OpenRoutes();U.controls.tabwelcome.scripts.OnClick();eq(U.tab,'welcome');eq(U.controls.import:IsVisible(),true)
 U.SetTab('resources');U.controls.resourceWelcome.scripts.OnClick();eq(U.tab,'welcome')
end)
test('Welcome import reports progress and prevents a second queued import',function()
 local A,U=setup();local calls=0
 A.Import=function() calls=calls+1;A.importJob=coroutine.create(function() end);A.status='Import queued for all available zones.' end
 U.Toggle();U.controls.import.scripts.OnClick();eq(calls,1);eq(U.controls.import:IsEnabled(),false)
 assert(U.welcomeView.status:GetText():find('queued',1,true));U.controls.import.scripts.OnClick();eq(calls,1)
 A.importJob=nil;A.status='Imported 100 locations across 2 zones.';U.Refresh();eq(U.controls.import:IsEnabled(),true);eq(U.controls.import:GetText(),'Import node data')
 assert(U.welcomeView.status:GetText():find('100 locations',1,true))
end)
test('Welcome navigation preserves a running route or unfinished draft',function()
 local A,U=setup();U.OpenRoutes();local route={name='Keep',mapID=1,points={point(.3),point(.5)}}
 A.follower=A.Follower.New(route,point(.1),distance);local follower=A.follower;U.SetTab('welcome');eq(A.follower,follower)
 U.welcomeView.routes.scripts.OnClick();eq(U.tab,'routes');eq(A.follower,follower)
 A.follower=nil;U.Edit(route);local editor=A.editor;U.SetTab('welcome');U.welcomeView.routes.scripts.OnClick();eq(A.editor,editor);eq(U.tab,'routes')
end)
