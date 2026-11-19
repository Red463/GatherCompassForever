local runtime={'Store','Client','Resources','MarkerGroups','SkillTooltip','Selection','Atlas','ResourceLibrary','DifficultyProbe','Gathering','Imports','Editor','Recorder','Corridor','Planner','FarmingSession','Follower','Heatmap','MiniHeat','MinimapPins','Map','Skin','PanelWindow','ScrollPanel','VirtualList','Dropdown','Arrow','MinimapButton','Data/MapReveal','MapOverlays','MapArt','GroupPicker','RouteSketch','RouteView','ResourceLibraryView','UIActions','FilterSidebar','WelcomeView','MarkerFiltersView','NodeDisplayView','PreferencesView','UI','Core'}
local function setup(saved,configure)
 dofile('tests/wow.lua'); fakeUI(); local A={}; GatherlyDB=saved
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
 A.OnEvent(nil,'ADDON_LOADED','Gatherly'); A.OnEvent(nil,'PLAYER_LOGIN')
 return A,function(t) clock=t end
end

test('Gatherly owns the addon identity saved variable and slash registration',function()
 local A=setup();eq(SLASH_GATHERLY1,'/gatherly');eq(SlashCmdList.GATHERLY,A.Command);eq(GatherlyDB,A.db)
 eq(A.MinimapButton.frame.name,'GatherlyMinimapButton');A.Command('');assert(A.UI.frame:IsShown())
end)

test('import works on each rendered frame with bounded chunks and immediate completion refresh',function()
 local A=setup();local produced=0;local refreshes=0;local old=A.UI.Refresh;A.UI.Refresh=function() refreshes=refreshes+1;old() end
 A.Imports.Provider=function() return function() return function()
  produced=produced+1;if produced>10000 then return end
  return produced,{mapID=(produced-1)%16+1,x=((math.floor((produced-1)/16)%100)+1)*.009,y=.01+math.floor((produced-1)/1600)*.03,kind='herb',materialID='gm:herb:401',name='Peacebloom'}
 end end,{direct=10000,fallback=0} end
 local profile=debugprofilestop;debugprofilestop=function() return 0 end
 A.Import();A.Tick(1/60);assert(produced>40,'Must not wait for navigation tick');assert(produced<=2048,'Frozen timer still needs work cap')
 for _=1,119 do if not A.importJob then break end;A.Tick(1/60) end
 eq(A.importJob,nil);eq(A.importIterator,nil);assert(A.status:find('10000 locations',1,true),tostring(A.status));assert(refreshes>=2,'Completion did not refresh: '..refreshes)
 debugprofilestop=profile
end)

test('import time budget yields before the work cap and a failing source can be retried safely',function()
 local A=setup();local produced=0;local failed=true;local stamps=0;local oldProfile=debugprofilestop
 debugprofilestop=function() stamps=stamps+4;return stamps end
 A.Imports.Provider=function() return function() local i=0;return function()
  i=i+1;produced=produced+1
  if failed and i==100 then error('source interrupted') end
  if i>200 then return end
  return i,{mapID=1,x=i*.004,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom'}
 end end,{direct=200,fallback=0} end
 A.Import();A.Tick(1/60);assert(produced<=128,'Profiler budget must yield before 2048 records');assert(A.importJob)
 for _=1,20 do if not A.importJob then break end;A.Tick(1/60) end
 eq(A.importJob,nil);eq(A.importIterator,nil);assert(A.status:find('source interrupted',1,true))
 local partial=#A.db.nodes[1];failed=false;A.Import();for _=1,20 do if not A.importJob then break end;A.Tick(1/60) end
 eq(A.importJob,nil);assert(#A.db.nodes[1]>=partial);assert(A.status:find('200 locations',1,true))
 for _,n in ipairs(A.db.nodes[1]) do eq(n.confirmed,nil) end
 debugprofilestop=oldProfile
end)

test('building a large existing-zone index yields and resumes without Lua 5.1 protected-call errors',function()
 local A=setup();local list={};for i=1,5000 do list[i]={mapID=1,x=(i%100)*.01,y=math.floor(i/100)*.01,kind='herb',materialID='gm:herb:401',name='Peacebloom',key='seed'..i,imported=true} end
 A.db.nodes[1]=list;A.db.nextNode=5001
 A.Imports.Provider=function() return function() local done=false;return function()
  if done then return end;done=true;return 1,{mapID=1,x=list[1].x,y=list[1].y,kind='herb',materialID='gm:herb:401',name='Peacebloom'}
 end end,{direct=1,fallback=0} end
 local oldProfile=debugprofilestop;debugprofilestop=function() return 0 end
 A.Import();A.Tick(1/60);assert(A.importJob,'Existing index construction must yield')
 for _=1,10 do if not A.importJob then break end;A.Tick(1/60) end
 eq(A.importJob,nil);eq(#A.db.nodes[1],5000);assert(A.status:find('Imported 1 locations',1,true))
 debugprofilestop=oldProfile
end)

test('unavailable native zone geometry imports through an exact index without quadratic API calls',function()
 local A=setup();local calls=0;C_Map.GetMapWorldSize=function() calls=calls+1 end
 local list={};for i=1,4000 do list[i]={mapID=1,x=(i%100)*.009,y=math.floor(i/100)*.009,kind='herb',materialID='gm:herb:401',name='Peacebloom',key='seed'..i,imported=true} end
 A.db.nodes[1]=list;A.db.nextNode=4001;A.UI.Refresh=function() end;A.Map.Refresh=function() end
 A.Imports.Provider=function() return function() local i=0;return function()
  i=i+1;if i>64 then return end
  return i,{mapID=1,x=.995,y=i*.005,kind='herb',materialID='gm:herb:401',name='Peacebloom'}
 end end,{direct=64,fallback=0} end
 local oldProfile=debugprofilestop;debugprofilestop=function() return 0 end
 A.Import();A.Tick(1/60);assert(calls<32,'Unavailable metrics performed '..calls..' API calls in one frame')
 for _=1,20 do if not A.importJob then break end;A.Tick(1/60) end
 eq(A.importJob,nil);eq(#A.db.nodes[1],4064);assert(calls<100)
 debugprofilestop=oldProfile
end)

test('throwing profiler APIs fall back safely and do not abort import',function()
 local A=setup();local oldProfile,oldPrecise=debugprofilestop,GetTimePreciseSec
 debugprofilestop=function() error('timer inaccessible') end;GetTimePreciseSec=function() error('precise timer inaccessible') end
 A.Imports.Provider=function() return function() local i=0;return function()
  i=i+1;if i>512 then return end
  return i,{mapID=1,x=i*.001,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom'}
 end end,{direct=512,fallback=0} end
 A.Import();for _=1,20 do if not A.importJob then break end;A.Tick(1/60) end
 eq(A.importJob,nil);assert(A.status:find('512 locations',1,true),tostring(A.status));assert(#A.db.nodes[1]>0)
 debugprofilestop=oldProfile;GetTimePreciseSec=oldPrecise
end)

test('import resume tokens revalidate metrics when the game clock is frozen',function()
 local A=setup();local width=1000;C_Map.GetMapWorldSize=function() return width,500 end
 local oldProfile=debugprofilestop;debugprofilestop=function() return 0 end
 A.Imports.Provider=function() return function() local i=0;return function()
  i=i+1;if i>2049 then return end
  if i~=1 and i~=2049 then return i,false end
  return i,{mapID=1,x=i==1 and .104 or .113,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf'}
 end end,{direct=2,fallback=0} end
 A.Import();A.Tick(1/60);assert(A.importJob);eq(#A.db.nodes[1],1)
 width=500;for _=1,10 do if not A.importJob then break end;A.Tick(1/60) end
 eq(A.importJob,nil);eq(#A.db.nodes[1],1);assert(A.status:find('Imported 2 locations',1,true))
 debugprofilestop=oldProfile
end)

test('real successful gathering events mark a future generated stop without importing pickup progress',function()
 local A,clock=setup();local nodes={}
 for i,x in ipairs({.2,.4,.6}) do nodes[i]=A.Store.Observe(A.db,{mapID=1,x=x,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'}) end
 A.UI.actions.generateStart();local follower=A.follower;assert(follower)
 local future=follower.route.points[2];local initial=follower.index
 local observation={mapID=1,x=future.x,y=future.y,kind='herb',materialID='gm:herb:401',source='imported'}
 A.Store.Observe(A.db,observation);eq(next(follower.collected),nil)
 A.Client.Position=function() return point(future.x,future.y) end
 A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Peacebloom','detour-1',2366)
 clock(1);A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','detour-1',2366);A.OnEvent(nil,'LOOT_READY');A.OnEvent(nil,'LOOT_OPENED')
 eq(follower.collected[2],true);eq(follower.index,initial);follower:Skip();assert(follower.index~=2)
 A.UI.actions.stop();eq(A.follower,nil)
end)

test('a confirmed known spawn outside the representative stops does not consume its neighbour',function()
 local A,clock=setup();local nodes={}
 for i,x in ipairs({.2,.21,.4}) do nodes[i]=A.Store.Observe(A.db,{mapID=1,x=x,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'}) end
 A.UI.actions.generateStart();local f=A.follower;eq(f.route.points[1].nodeKey,nodes[1].key)
 A.Client.Position=function() return point(.21) end;A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Peacebloom','adjacent',2366)
 clock(1);A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','adjacent',2366);A.OnEvent(nil,'LOOT_READY')
 eq(nodes[2].confirmed,true);eq(next(f.collected),nil);eq(f.index,1)
end)

test('loot delayed across a lap boundary never consumes a stop on the next lap',function()
 local A,clock=setup();for _,x in ipairs({.2,.4,.6}) do A.Store.Observe(A.db,{mapID=1,x=x,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'}) end
 A.UI.actions.generateStart();local f=A.follower;f.index=3;f.lapSeen={[1]=true,[2]=true};f.lapCount=2
 A.Client.Position=function() return point(.6) end
 A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Peacebloom','lap-end',2366);clock(1);A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','lap-end',2366)
 clock(1.1);A.Tick(.1);eq(f.lap,1);clock(1.2);A.OnEvent(nil,'LOOT_READY');eq(next(f.collected),nil)
 f:Skip();f:Skip();eq(f.index,3);eq(f.lap,1)
end)

test('a pending gather from an old route cannot consume a fresh route but survives an in-session edit',function()
 for _,replace in ipairs({true,false}) do
  local A,clock=setup();local nodes={};for i,x in ipairs({.2,.4,.6}) do nodes[i]=A.Store.Observe(A.db,{mapID=1,x=x,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'}) end
  A.UI.actions.generateStart();A.Client.Position=function() return point(.4) end
  A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Peacebloom','pending',2366)
  if replace then A.UI.actions.generateStart() else A.plan.selected=nodes[3].key;A.UI.actions.removeNode() end
  A.follower:Pause();clock(1);A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','pending',2366);A.OnEvent(nil,'LOOT_READY')
  if replace then eq(next(A.follower.collected),nil) else assert(next(A.follower.collected)) end
 end
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

test('generation and Atlas use contextual names without saving or changing archived routes',function()
 local A=setup();A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
 A.UI.actions.generateReview();eq(A.plan.route.name,'Test Zone - Silverleaf Loop');eq(next(A.db.routes),nil)
 local first=A.Store.SaveRoute(A.db,A.plan.route);A.UI.actions.generateReview();eq(A.plan.route.name,'Test Zone - Silverleaf Loop (2)')
 A.UI.SetTab('codex');A.UI.codexView.SetSearch('Silverleaf');A.UI.codexView.tiles[1].scripts.OnClick(A.UI.codexView.tiles[1]);A.UI.codexView.Plan();eq(A.plan.route.name,'Test Zone - Silverleaf Loop (2)')
 eq(A.db.routes[first].name,'Test Zone - Silverleaf Loop')
end)


test('starting or explicitly opening a route restores its world line after resource map focus',function()
 local A=setup();A.selectedRoute=A.Store.SaveRoute(A.db,{name='Visible',mapID=1,points={point(.3),point(.5)}})
 A.UI.OpenRoutes();assert(A.Map.SetNodeFocus(1,{['gm:herb:401']=true}));A.UI.actions.start();eq(A.Map.nodeFocus,nil)
 A.Tick(.5);assert(A.Map.worldLines[1]:IsShown())
 assert(A.Map.SetNodeFocus(1,{['gm:herb:401']=true}));A.UI.OpenRoutes();A.UI.actions.map();eq(A.Map.nodeFocus,nil)
 A.Tick(.5);assert(A.Map.worldLines[1]:IsShown())
end)
test('arrival preference updates an already running route immediately',function()
 local A,clock=setup();A.db.settings.arrival=5
 A.selectedRoute=A.Store.SaveRoute(A.db,{name='Live arrival',mapID=1,points={point(.3)}})
 A.UI.actions.start();eq(A.follower.arrival,5)
 A.UI.controls.arrival.scripts.OnValueChanged(A.UI.controls.arrival,15)
 eq(A.db.settings.arrival,15);eq(A.follower.arrival,15)
 A.Client.Position=function() return point(.29) end;clock(1);A.Tick(.1);eq(A.follower.status,'complete')
end)

test('startup gather generate save follow and shared arrow map target cooperate',function()
 local A,clock=setup(); assert(A.initialized); eq(SLASH_GATHERLY1,'/gatherly'); eq(SlashCmdList.GATHERLY,A.Command)
 local saved=A.db; A.OnEvent(nil,'ADDON_LOADED','Gatherly'); eq(A.db,saved)
 A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Peacebloom','cast-1',2366)
 clock(1); A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','cast-1',2366); A.OnEvent(nil,'LOOT_READY'); A.OnEvent(nil,'LOOT_OPENED')
 eq(A.detector.reason,nil)
 local nodes=A.UI.SelectedNodes(); eq(#nodes,1); eq(nodes[1].count,1); eq(nodes[1].lastGathered,100000)
 A.UI.controls.generateReview.scripts.OnClick(); assert(A.plan);eq(A.editor,nil);eq(next(A.db.routes),nil)
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
 eq(GatherlyDB,old); eq(old.precious,'keep'); eq(A.writable,false)
 C_Map=nil; GetPlayerFacing=nil; A.Tick(.5); A.Command(''); eq(A.UI.frame:IsShown(),true)
 assert(A.UI.status:GetText():find('Position unavailable'))
end)
test('Welcome queues a real all-zone batch import and arrow navigation still opens Routes',function()
 local A=setup();A.Command('');eq(A.UI.tab,'welcome')
 A.Imports.Provider=function()
  return function()
   return function(_,key)
    local i=(key or 0)+1;if i>80 then return end
    return i,{mapID=i<=40 and 1 or 2,x=.01*((i-1)%40+1),y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom'}
   end,nil,0
  end,{direct=80,fallback=0}
 end
 A.UI.controls.import.scripts.OnClick();assert(A.importJob);eq(A.UI.controls.import:IsEnabled(),false)
 A.Tick(.1);A.Tick(.1);A.Tick(.5);eq(A.importJob,nil)
 eq(#A.Store.Select(A.db,1,{source='imported'}),40);eq(#A.Store.Select(A.db,2,{source='imported'}),40)
 assert(A.UI.welcomeView.status:GetText():find('80 locations across 2 zones',1,true));eq(A.UI.controls.import:IsEnabled(),true)
 A.Arrow.frame.scripts.OnMouseUp(A.Arrow.frame,'LeftButton');eq(A.UI.tab,'routes')
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
 eq(SlashCmdList.GATHERLY,A.Command);A.Command('');eq(A.UI.frame:IsShown(),true)
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
 A.Command('');eq(A.UI.frame:IsShown(),true);assert(A.UI.controls.generateStart)
end)
test('a panel construction error keeps slash diagnostics registered and hides the partial window',function()
 local A=setup(nil,function(addon) addon.Skin.Window=function() error('test panel construction failure') end end)
 eq(SlashCmdList.GATHERLY,A.Command);assert(not A.initialized)
 assert(A.uiError:find('test panel construction failure',1,true));eq(A.UI.frame:IsShown(),false)
 local saved=GatherlyDB;local message;A.Print=function(text) message=text end
 A.Command('status');assert(message:find('test panel construction failure',1,true));eq(GatherlyDB,saved)
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


test('inspect commands retain the native probe without a diagnostic button on the normal panel',function()
 local A=setup();local arm,report,cancel=0,0,0
 A.DifficultyProbe={Arm=function() arm=arm+1;return true end,Report=function() report=report+1 end,Cancel=function() cancel=cancel+1 end}
 A.UI.frame:Hide();A.Command('inspect');eq(arm,1);eq(A.UI.frame:IsShown(),false)
 A.Command('inspect report');eq(report,1);A.Command('inspect off');eq(cancel,1)
 A.UI.OpenRoutes();A.UI.SetTab('nodes');eq(A.UI.controls.inspectNode,nil);eq(arm,1)
end)
