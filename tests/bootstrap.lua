local runtime={'Store','Client','Resources','Atlas','ResourceLibrary','DifficultyProbe','Gathering','Imports','Editor','Recorder','Planner','Follower','Map','Skin','Dropdown','Arrow','MinimapButton','RouteSketch','AtlasView','ResourceLibraryView','UIActions','UI','Core'}
local function setup(saved,configure)
 dofile('tests/wow.lua'); fakeUI(); local A={}; GatherCompassForeverDB=saved
 C_Map={GetBestMapForUnit=function() return 1 end,GetPlayerMapPosition=function() return {GetXY=function() return .2,.5 end} end,GetMapWorldSize=function() return 1000,500 end,GetMapInfo=function() return {name='Test Zone'} end}
 local clock=0; GetTime=function() return clock end; time=function() return 100000 end; GetPlayerFacing=function() return 0 end
 C_Spell={GetSpellName=function(id) return id==2366 and 'Herbalism' or id==2575 and 'Mining' or nil end}
 GetNumLootItems=function() return 1 end; GetLootSlotLink=function() return 'item:2447' end
 GetLootSourceInfo=function() return 'GameObject-0-1-1-1-1618-00001',1 end
 C_Item={GetItemNameByID=function(id) return id==2447 and 'Peacebloom' end}
 C_Minimap={GetViewRadius=function() return 200 end}; GetCVar=function() return '0' end
 GatherMate2=nil; LibStub=nil; GatherMateData2HerbDB=nil; GatherMateData2MineDB=nil; C_AddOns=nil
 for _,name in ipairs(runtime) do module(name,A) end
 if configure then configure(A) end
 A.OnEvent(nil,'ADDON_LOADED','GatherCompassForever'); A.OnEvent(nil,'PLAYER_LOGIN')
 return A,function(t) clock=t end
end

local function deleteSetup()
 local prompt
 StaticPopupDialogs={};StaticPopup_Show=function(which,name,unused,data) prompt={which=which,name=name,data=data};return prompt end
 local A=setup();local first=A.Store.SaveRoute(A.db,{mapID=1,name='First | trail',points={point(.3),point(.4)}})
 local second=A.Store.SaveRoute(A.db,{mapID=1,name='Second',points={point(.5),point(.6)}})
 A.selectedRoute=first;A.UI.OpenRoutes()
 return A,first,second,function() return prompt end,function() local p=prompt;StaticPopupDialogs[p.which].OnAccept({},p.data) end
end

test('Delete route requires a named confirmation and acts on its captured route',function()
 local A,first,second,prompt,accept=deleteSetup();assert(A.UI.controls.deleteRoute)
 A.UI.controls.deleteRoute.scripts.OnClick();assert(A.db.routes[first]);eq(prompt().name,'First || trail')
 A.UI.SelectRoute(second);accept();eq(A.db.routes[first],nil);assert(A.db.routes[second]);eq(A.selectedRoute,second)
 A.UI.controls.deleteRoute.scripts.OnClick();assert(A.db.routes[second]);accept();eq(next(A.db.routes),nil);eq(A.selectedRoute,nil)
 eq(A.UI.empty:IsShown(),true);eq(A.UI.detail:IsShown(),false)
end)

test('Delete route revalidates changed routes and unfinished drafts before accepting',function()
 local A,first,second,prompt,accept=deleteSetup();A.UI.actions.deleteRoute()
 A.Store.SaveRoute(A.db,{id=first,mapID=1,name='Updated',points={point(.3)}});accept();eq(A.db.routes[first].name,'Updated')
 A.UI.actions.deleteRoute();A.editor=A.Editor.New(A.db.routes[first]);accept();assert(A.db.routes[first]);assert(A.editor)
 A.editor=nil;StaticPopup_Show=nil;A.UI.actions.deleteRoute();assert(A.db.routes[first]);assert(A.status:find('confirmation',1,true))
end)

test('deleting the followed route clears guidance while deleting a different route preserves it',function()
 local A,first,second,prompt,accept=deleteSetup();A.UI.actions.start();A.Tick(.1);local following=A.follower;assert(following)
 A.UI.OpenRoutes();A.UI.SelectRoute(second);A.mapPreviewRoute=A.db.routes[second];A.UI.actions.deleteRoute();accept()
 eq(A.follower,following);eq(A.mapPreviewRoute,nil);eq(A.db.routes[second],nil);assert(A.db.routes[first])
 A.selectedRoute=first;A.UI.Refresh();A.UI.actions.deleteRoute();accept();eq(A.follower,nil);eq(A.Arrow.frame:IsShown(),false)
 eq(next(A.db.routes),nil);for _,line in ipairs(A.Map.miniLines) do eq(line:IsShown(),false) end
end)

test('deleting from a later route page keeps the new selection visible and clamps the last page',function()
 local A,first,second,prompt,accept=deleteSetup()
 for i=1,9 do A.Store.SaveRoute(A.db,{mapID=1,name=string.format('Saved %02d',i),points={point(.3)}}) end
 A.UI.routePage=2;A.UI.Refresh();A.UI.SelectRoute(A.UI.cards[1].routeID);A.UI.actions.deleteRoute();accept()
 eq(A.UI.routePage,2)
 local visible=false;for _,row in ipairs(A.UI.cards) do if row:IsShown() and row.routeID==A.selectedRoute then visible=true end end
 assert(visible,'Deletion selects a route outside the visible page')
 while A.UI.routePage==2 do A.UI.SelectRoute(A.UI.cards[1].routeID);A.UI.actions.deleteRoute();accept() end
 eq(A.UI.routePage,1);eq(A.UI.controls.nextRoute:IsEnabled(),false)
end)

test('minimap launcher builds once at startup and its preference can restore a hidden button',function()
 local A=setup();assert(A.initialized);local b=A.MinimapButton.frame;assert(b and b:IsShown())
 A.UI.frame:Hide();b.scripts.OnClick(b,'LeftButton');eq(A.UI.frame:IsShown(),true)
 A.UI.SetTab('settings');local check=A.UI.controls.minimapButton;assert(check);eq(check:GetChecked(),true)
 check:SetChecked(false);check.scripts.OnClick(check);eq(b:IsShown(),false)
 A.UI.frame:Hide();A.Command('');eq(A.UI.frame:IsShown(),true)
 check:SetChecked(true);check.scripts.OnClick(check);eq(b:IsShown(),true)
 A.OnEvent(nil,'PLAYER_LOGIN');eq(A.MinimapButton.frame,b)
end)

test('normal generation and atlas plans use contextual unique names and retain editable names',function()
 local A=setup();A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
 A.UI.actions.generate();eq(A.editor.draft.name,'Test Zone - Silverleaf Loop');eq(A.UI.name:GetText(),A.editor.draft.name)
 A.UI.actions.save();local first=A.selectedRoute;A.UI.actions.generate();eq(A.editor.draft.name,'Test Zone - Silverleaf Loop (2)')
 A.UI.name:SetText('My river trail');A.UI.actions.save();eq(A.db.routes[A.selectedRoute].name,'My river trail')
 A.UI.SetTab('atlas');A.UI.atlasView.Plan();eq(A.editor.draft.name,'Test Zone - Silverleaf Loop (2)')
 eq(A.db.routes[first].name,'Test Zone - Silverleaf Loop')
end)

test('Edit path opens map editing immediately with instructions and a route panel return',function()
 local A=setup();local mapID;WorldMapFrame.SetMapID=function(_,id) mapID=id end
 A.selectedRoute=A.Store.SaveRoute(A.db,{name='Edit me',mapID=1,points={point(.3),point(.5)}})
 A.UI.OpenRoutes();A.UI.actions.edit();assert(A.editor);eq(mapID,1);eq(WorldMapFrame:IsShown(),true);eq(A.UI.frame:IsShown(),false)
 assert(A.Map.editorHelp and A.Map.editorHelp:IsShown());assert(A.Map.editorHelp.instructions:GetText():find('Drag',1,true))
 A.Map.editorHelp.back.scripts.OnClick();eq(WorldMapFrame:IsShown(),false);eq(A.UI.frame:IsShown(),true);assert(A.editor)
 assert(A.UI.controls.workMap:GetText():find('Edit',1,true))
 A.UI.controls.workMap.scripts.OnClick();eq(A.UI.frame:IsShown(),false)
 A.editor:Move(1,point(.4));A.Map.editorHelp.save.scripts.OnClick();eq(A.editor,nil)
 near(A.db.routes[A.selectedRoute].points[1].x,.4);eq(A.UI.frame:IsShown(),true);eq(WorldMapFrame:IsShown(),false)
end)

test('starting or explicitly opening a route restores its world line after resource map focus',function()
 local A=setup();A.selectedRoute=A.Store.SaveRoute(A.db,{name='Visible',mapID=1,points={point(.3),point(.5)}})
 A.UI.OpenRoutes();assert(A.Map.SetNodeFocus(1,{['gm:herb:401']=true}));A.UI.actions.start();eq(A.Map.nodeFocus,nil)
 A.Tick(.5);assert(A.Map.worldLines[1]:IsShown())
 assert(A.Map.SetNodeFocus(1,{['gm:herb:401']=true}));A.UI.OpenRoutes();A.UI.actions.map();eq(A.Map.nodeFocus,nil)
 A.Tick(.5);assert(A.Map.worldLines[1]:IsShown())
end)
test('startup gather generate save follow and shared arrow map target cooperate',function()
 local A,clock=setup(); assert(A.initialized); eq(SLASH_GATHERCOMPASSFOREVER1,'/gcf'); eq(SlashCmdList.GATHERCOMPASSFOREVER,A.Command)
 local saved=A.db; A.OnEvent(nil,'ADDON_LOADED','GatherCompassForever'); eq(A.db,saved)
 A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Peacebloom','cast-1',2366)
 clock(1); A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','cast-1',2366); A.OnEvent(nil,'LOOT_READY'); A.OnEvent(nil,'LOOT_OPENED')
 eq(A.detector.reason,nil)
 local nodes=A.UI.SelectedNodes(); eq(#nodes,1); eq(nodes[1].count,1); eq(nodes[1].lastGathered,100000)
 A.UI.controls.generate.scripts.OnClick(); assert(A.editor); A.UI.controls.save.scripts.OnClick(); assert(A.selectedRoute)
 A.UI.controls.start.scripts.OnClick(); assert(A.follower); A.Tick(.5)
 eq(A.Map.targetIndex,A.follower.index); assert(A.Arrow.frame); eq(A.Arrow.frame:IsShown(),true)
 A.UI.controls.pause.scripts.OnClick(); A.Tick(.5); eq(A.Arrow.frame:IsShown(),true); eq(A.Arrow.frame.icon:IsShown(),false)
 A.Import(); assert(A.status:find('GatherMate2'))
end)
test('global import works without player position and reads every zone beyond ten thousand rows',function()
 local A=setup(); A.Client.Position=function() return nil end
 GatherMateData2HerbDB={[10]={},[20]={}}; GatherMateData2MineDB={[30]={[2000300000]=201}}
 for i=1,10005 do GatherMateData2HerbDB[10][i*100000+100]=401 end
 GatherMateData2HerbDB[20][3000400000]=401
 GatherMate2={gmdbs={},GetNodesForZone=function() return pairs({}) end,
  DecodeLoc=function(_,loc) return math.floor(loc/1000000)/10000,math.floor(loc%1000000/100)/10000 end,
  GetNameForNode=function(_,kind) return kind=='Mining' and 'Copper Vein' or 'Peacebloom' end}
 A.Import(); assert(A.importJob,'Import must not require player position')
 for i=1,3000 do A.Tick(.1); if not A.importJob then break end end
 assert(not A.importJob,'Import did not finish')
 assert(A.db.nodes[20] and A.db.nodes[30],'Every source zone must be imported')
 assert(A.status:find('10007') and A.status:find('3 zones'),'No 10,000-row truncation')
 GatherMateData2HerbDB=nil; GatherMateData2MineDB=nil; GatherMate2=nil
end)
test('missing gathering and facing capabilities have visible reasons',function()
 local A=setup(); A.UI.frame:Show(); GetLootSourceInfo=nil; GetPlayerFacing=nil; A.UI.Refresh()
 assert(A.UI.status:GetText():find('loot'),'Missing loot must be explained')
 assert(A.UI.status:GetText():find('facing'),'Missing facing must be explained')
end)
test('multi source loot is rejected as a whole before recording any source',function()
 local A,clock=setup(); A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Peacebloom','cast-1',2366)
 clock(1); A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','cast-1',2366)
 GetLootSourceInfo=function() return 'GameObject-0-1-1-1-1618-00001',1,'GameObject-0-1-1-1-1731-00002',1 end
 A.OnEvent(nil,'LOOT_READY'); eq(#A.UI.SelectedNodes(),0)
 assert(A.detector.reason and A.detector.reason:find('source'))
end)
test('unknown schema preserved and absent APIs leave UI usable',function()
 local old={version=77,precious='keep'}; local A=setup(old)
 eq(GatherCompassForeverDB,old); eq(old.precious,'keep'); eq(A.writable,false)
 C_Map=nil; GetPlayerFacing=nil; A.Tick(.5); A.Command(''); eq(A.UI.frame:IsShown(),true)
 assert(A.UI.status:GetText():find('Position unavailable'))
end)
test('live GatherMate provider imports through Core in batches and never confirms',function()
 local A=setup(); local data={ [20003000]=401,[40005000]=402 }
 GatherMate2={gmdbs={['Herb Gathering']={[1]=data}},
  GetNodesForZone=function(_,map,kind) eq(map,1); eq(kind,'Herb Gathering'); return pairs(data) end,
  DecodeLoc=function(_,coord) return math.floor(coord/1000000)/10000,math.floor(coord%1000000/100)/10000 end,
  GetNameForNode=function(_,_,id) return id==401 and 'Peacebloom' or 'Silverleaf' end}
 A.Import(); for i=1,5 do A.Tick(.1) end
 local imported=A.Store.Select(A.db,1,{source='imported'}); eq(#imported,2); eq(imported[1].confirmed,nil)
 A.Import(); for i=1,5 do A.Tick(.1) end; eq(#A.db.nodes[1],2)
 eq(data[20003000],401); GatherMate2=nil
end)
test('empty installed GatherMate database explains starter data import instead of success zero',function()
 local A=setup(); GatherMate2={gmdbs={['Herb Gathering']={},Mining={}},
  GetNodesForZone=function() return pairs({}) end,DecodeLoc=function() end,GetNameForNode=function() end}
 A.Import(); for i=1,3 do A.Tick(.1) end
 assert(not A.status:find('Imported 0'),'Empty source is not a successful import')
 assert(A.status:find('GatherMate2_Data') and A.status:find('Import'),'Explain the required starter data import')
 GatherMate2=nil
end)
test('Import button loads data pack directly without populating GatherMate database',function()
 local A=setup(); local loads=0; local herb={[2000300000]=401}; local ore={[4500550000]=201}
 GatherMate2={gmdbs={['Herb Gathering']={},Mining={}},
  GetNodesForZone=function() return pairs({}) end,
  DecodeLoc=function(_,loc) return math.floor(loc/1000000)/10000,math.floor(loc%1000000/100)/10000 end,
  GetNameForNode=function(_,kind,id) return kind=='Mining' and 'Copper Vein' or 'Peacebloom' end}
 C_AddOns={LoadAddOn=function(name) eq(name,'GatherMate2_Data'); loads=loads+1; GatherMateData2HerbDB={[1]=herb}; GatherMateData2MineDB={[1]=ore}; return true end}
 A.Import(); for i=1,6 do A.Tick(.1) end
 local nodes=A.Store.Select(A.db,1,{source='imported'}); eq(#nodes,2); eq(loads,1)
 near(nodes[1].x,.2); near(nodes[1].y,.3); eq(nodes[1].confirmed,nil)
 eq(next(GatherMate2.gmdbs.Mining),nil); eq(herb[2000300000],401); eq(ore[4500550000],201)
 assert(A.status:find('GatherMate2_Data'))
 A.Import(); for i=1,6 do A.Tick(.1) end; eq(#A.db.nodes[1],2); eq(loads,1)
end)
test('blocked data pack explains dependency while cleared raw tables use GatherMate fallback',function()
 local A=setup(); local rows={}; GatherMate2={gmdbs={Mining={[1]=rows}},
  GetNodesForZone=function() return pairs(rows) end,
  DecodeLoc=function() return .2,.3 end,GetNameForNode=function() return 'Copper Vein' end}
 C_AddOns={LoadAddOn=function() return nil,'DISABLED' end}
 A.Import(); for i=1,3 do A.Tick(.1) end; assert(A.status:find('DISABLED'))
 rows[2000300000]=201
 A.Import(); for i=1,3 do A.Tick(.1) end; eq(#A.Store.Select(A.db,1,{source='imported'}),1)
 GatherMateData2HerbDB=nil; GatherMateData2MineDB=nil; C_AddOns=nil; GatherMate2=nil
end)
test('English mining fallback records repeated successful ore loots once per cast',function()
 local A,clock=setup(); GetLootSlotLink=function() return 'item:2770' end
 GetLootSourceInfo=function() return 'GameObject-0-1-1-1-1731-00001',1 end
 for i=1,2 do
  clock(i*3); A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Copper Vein','ore-'..i,2575)
  clock(i*3+1); A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','ore-'..i,2575)
  A.OnEvent(nil,'LOOT_READY'); A.OnEvent(nil,'LOOT_OPENED')
 end
 local nodes=A.UI.SelectedNodes(); eq(#nodes,1); eq(nodes[1].kind,'ore'); eq(nodes[1].count,2)
end)

test('Forever startup uses supported tabs and registers the slash command',function()
 local A=setup();assert(A.initialized);eq(A.UI.tabs.routes.template,'PanelTopTabButtonTemplate')
 eq(SlashCmdList.GATHERCOMPASSFOREVER,A.Command);A.Command('');eq(A.UI.frame:IsShown(),true)
end)
test('missing optional tab template falls back without aborting startup',function()
 local A=setup(nil,function()
  local create=CreateFrame
  CreateFrame=function(kind,name,parent,template)
   if template=='PanelTabButtonTemplate' or template=='PanelTopTabButtonTemplate' then error('optional tab template unavailable') end
   return create(kind,name,parent,template)
  end
 end)
 assert(A.initialized);eq(A.UI.tabs.routes.tabFallback,true)
 A.Command('');eq(A.UI.frame:IsShown(),true);assert(A.UI.controls.generate)
end)
test('a panel construction error keeps slash diagnostics registered and hides the partial window',function()
 local A=setup(nil,function(addon) addon.Skin.Window=function() error('test panel construction failure') end end)
 eq(SlashCmdList.GATHERCOMPASSFOREVER,A.Command);assert(not A.initialized)
 assert(A.uiError:find('test panel construction failure',1,true));eq(A.UI.frame:IsShown(),false)
 local saved=GatherCompassForeverDB;local message;A.Print=function(text) message=text end
 A.Command('status');assert(message:find('test panel construction failure',1,true));eq(GatherCompassForeverDB,saved)
 A.Tick(1);eq(A.UI.frame:IsShown(),false)
end)


for _,mode in ipairs({'button','command'}) do
 test(mode..' stop clears minimap route immediately and later ticks cannot redraw it',function()
  local A=setup()
  LibStub=function() return {AddWorldMapIconMap=function() end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
  local node=A.Store.Observe(A.db,{mapID=1,x=.32,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='confirmed'})
  A.selectedRoute=A.Store.SaveRoute(A.db,{name='Stop regression',mapID=1,loop=true,points={point(.3),point(.4)}})
  A.UI.controls.start.scripts.OnClick();A.Tick(.5)
  local visible=0;for _,line in ipairs(A.Map.miniLines) do if line:IsShown() then visible=visible+1 end end
  assert(visible>0,'Fixture must draw active minimap guidance')
  local target=A.Map.byKey['m:point:'..A.follower.index];assert(target)
  if mode=='command' then A.Command('stop') else A.UI.controls.stop.scripts.OnClick() end
  eq(A.follower,nil)
  for _,line in ipairs(A.Map.miniLines) do eq(line:IsShown(),false) end
  eq(target:IsShown(),false);eq(A.Arrow.frame:IsShown(),false);eq(A.Map.targetIndex,nil)
  assert(A.Map.byKey['m:node:'..node.key],'Known resource markers must remain')
  assert(A.selectedRoute and A.db.routes[A.selectedRoute],'Stop must preserve the saved selection')
  for i=1,3 do A.Tick(.5);for _,line in ipairs(A.Map.miniLines) do eq(line:IsShown(),false) end end
  for _,pool in ipairs({A.Map.worldLines,A.Map.worldShadows}) do for _,line in ipairs(pool) do eq(line:IsShown(),false) end end
  A.UI.actions.map();A.Tick(.5)
  for _,line in ipairs(A.Map.worldLines) do eq(line:IsShown(),false) end
  LibStub=nil
 end)
end

test('completed navigation retires minimap route without removing the saved route',function()
 local A=setup();A.selectedRoute=A.Store.SaveRoute(A.db,{name='Complete',mapID=1,points={point(.3),point(.4)}})
 A.UI.controls.start.scripts.OnClick();A.Tick(.5);assert(A.Map.miniLines[1]:IsShown())
 A.follower:Skip();A.follower:Skip();eq(A.follower.status,'complete');A.Tick(.5)
 for _,line in ipairs(A.Map.miniLines) do eq(line:IsShown(),false) end
 for _,line in ipairs(A.Map.worldLines) do eq(line:IsShown(),false) end
 eq(A.Map.targetIndex,nil);assert(A.db.routes[A.selectedRoute]);eq(A.Arrow.frame:IsShown(),false)
end)


test('inspect commands and node display button invoke the native probe without opening another panel',function()
 local A=setup();local arm,report,cancel=0,0,0
 A.DifficultyProbe={Arm=function() arm=arm+1;return true end,Report=function() report=report+1 end,Cancel=function() cancel=cancel+1 end}
 A.UI.frame:Hide();A.Command('inspect');eq(arm,1);eq(A.UI.frame:IsShown(),false)
 A.Command('inspect report');eq(report,1);A.Command('inspect off');eq(cancel,1)
 A.UI.OpenRoutes();A.UI.SetTab('nodes');assert(A.UI.controls.inspectNode)
 A.UI.controls.inspectNode.scripts.OnClick();eq(arm,2);eq(A.UI.frame:IsShown(),false)
end)
