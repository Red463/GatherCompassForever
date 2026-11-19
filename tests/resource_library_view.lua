local function viewSetup()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Editor','Recorder','Planner','Follower'}) do module(name,A) end
 moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.Resources.Skills=function() return {herb=109,ore=260},{herb={maxRank=150,bonus=0},ore={maxRank=300,bonus=0}} end
 A.UI.Build();A.UI.window:SetPreset('small');A.UI.OpenRoutes();A.UI.SetTab('resources');assert(A.UI.resourceLibraryView);return A,A.UI.resourceLibraryView
end
local function add(A,map,x,id,name,kind)
 A.Store.Observe(A.db,{mapID=map,x=x,y=.5,kind=kind or 'herb',materialID='gm:'..(kind or 'herb')..':'..id,name=name,source='imported'})
end

test('Resources is a full-width grid with independent type search and scrolling square item buttons',function()
 local A,V=viewSetup();eq(A.UI.tab,'codex');eq(A.UI.sidebar:IsShown(),false);eq(A.UI.content:GetWidth(),A.UI.frame:GetWidth()-24)
 assert(#V.model.items>35);assert(#V.tiles<=54);eq(V.tiles[1].cell:GetWidth(),V.tiles[1].cell:GetHeight())
 V.gridList:SetOffset(96);assert(V.gridList.scroller.offset>0)
 A.UI.controls.resourceType:SelectValue('ore');eq(V.kind,'ore');eq(V.gridList.scroller.offset,0)
 V.SetSearch('copper');eq(#V.model.items,1);eq(V.tiles[1].item.itemID,2770);eq(V.tiles[1].label:GetText(),'Copper Ore')
 eq(A.db.settings.kind,'both');eq(A.db.settings.materials,nil)
 V.SetSearch('%');eq(#V.model.items,0);eq(V.empty:IsShown(),true)
 A.UI.controls.resourceClear.scripts.OnClick();assert(#V.model.items>1)
end)

test('resource square opens a detail page and Back restores exact grid state',function()
 local A,V=viewSetup();V.gridList:SetOffset(96);local offset=V.gridList.scroller.offset
 local item=V.tiles[1].item;V.tiles[1].scripts.OnClick(V.tiles[1]);eq(V.mode,'detail');eq(V.item.id,item.id)
 eq(V.detail:IsShown(),true);eq(V.grid:IsShown(),false);eq(V.name:GetText(),item.name)
 A.UI.controls.resourceBack.scripts.OnClick();eq(V.mode,'grid');eq(V.gridList.scroller.offset,offset);eq(V.tiles[1].item.id,item.id)
 V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1]);V.Back();eq(V.search,'Silverleaf');eq(#V.model.items,1)
end)

test('zero-data items show honest missing locations while multi-source ore shows both requirements',function()
 local A,V=viewSetup();V.SetSearch('Black Lotus');V.tiles[1].scripts.OnClick(V.tiles[1]);eq(V.item.count,0);eq(V.zoneEmpty:IsShown(),true)
 assert(not V.zoneRows[1] or not V.zoneRows[1]:IsShown());assert(V.zoneEmpty:GetText():find('No known locations',1,true))
 V.Back();add(A,2,.2,214,'Small Thorium Vein','ore');add(A,1,.3,215,'Rich Thorium Vein','ore');V.SetSearch('Thorium')
 V.tiles[1].scripts.OnClick(V.tiles[1]);eq(V.item.count,2);eq(V.item.name,'Thorium Ore')
 assert(V.sourceRows[1].requirement:GetText():find('245',1,true));assert(V.sourceRows[2].requirement:GetText():find('275',1,true))
 eq(V.zoneRows[1].zone.mapID,1);eq(V.zoneRows[2].zone.mapID,2)
end)

test('resource zone focus preserves navigation and filters and guards unfinished work',function()
 local A,V=viewSetup();add(A,2,.2,402,'Silverleaf');add(A,1,.3,402,'Silverleaf')
 A.db.settings.materials={unrelated=true,['gm:herb:402']=true};A.db.settings.kind='herb';A.db.settings.source='imported'
 V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1]);eq(V.item.count,2)
 local following=A.Follower.New({mapID=1,points={point(.5),point(.6)}},point(.1),distance);A.follower=following
 local focus,refreshed,mapID
 A.Map={SetNodeFocus=function(id,materials,key,source) focus={id=id,materials=materials,source=source};return true end,
  Refresh=function(db,route,follower) eq(db,A.db);eq(route,following.route);eq(follower,following);refreshed=true end}
 WorldMapFrame.SetMapID=function(_,id) mapID=id end
 V.ShowZone(2);eq(focus.id,2);eq(focus.materials['gm:herb:402'],true);eq(focus.source,'combined');eq(mapID,2);eq(refreshed,true)
 eq(A.follower,following);eq(A.db.settings.kind,'herb');eq(A.db.settings.materials.unrelated,true);eq(A.UI.frame:IsShown(),false)
 A.UI.frame:Show();A.editor=A.Editor.New({mapID=1,name='Keep',points={point(.2)}});A.UI.Refresh();focus=nil;V.ShowZone(1)
 eq(focus,nil);eq(A.editor.draft.name,'Keep');eq(A.UI.frame:IsShown(),true)
end)

test('resource page skips hidden or compact work and restores the original sidebar layout',function()
 local A,V=viewSetup();local calls=0;local query=A.ResourceLibrary.Query
 A.ResourceLibrary.Query=function(...) calls=calls+1;return query(...) end
 A.UI.frame:Hide();A.UI.Refresh();eq(calls,0);A.UI.frame:Show();A.UI.SetCompact(true);A.UI.Refresh();eq(calls,0)
 A.UI.SetCompact(false);assert(calls>0);A.UI.SetTab('settings');calls=0;A.UI.Refresh();eq(calls,0)
 eq(A.UI.sidebar:IsShown(),false);eq(A.UI.content:GetWidth(),A.UI.frame:GetWidth()-24);eq(A.UI.resourceLibraryView.frame:IsShown(),false)
 A.UI.SetTab('resources');eq(A.UI.sidebar:IsShown(),false);eq(A.UI.content:GetWidth(),A.UI.frame:GetWidth()-24)
end)

test('resource zone scrolling refreshes after imports and draft guards cover recording states',function()
 local A,V=viewSetup();for map=1,40 do add(A,map,.2,402,'Silverleaf') end
 V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1]);eq(#V.item.zones,40)
 V.zoneList:SetOffset(10000);assert(V.zoneList.scroller.offset>0);local last=false;for _,r in ipairs(V.zoneRows) do if r.zone and r.zone.mapID==40 then last=true end end;assert(last)
 add(A,40,.3,402,'Silverleaf');A.UI.Refresh();eq(V.item.zones[1].mapID,40);eq(V.item.count,41)
 V.Back();V.searchBox:SetText('Copper');V.searchBox.scripts.OnTextChanged(V.searchBox)
 eq(V.search,'Copper');eq(V.gridList.scroller.offset,0);eq(#V.model.items,1);eq(A.UI.controls.resourceType:GetValue(),'all')
 V.SetSearch('Silverleaf');V.tiles[1].scripts.OnClick(V.tiles[1]);local focused=false;A.Map={SetNodeFocus=function() focused=true end}
 for _,state in ipairs({'recording','recordedDraft'}) do
  A[state]={mapID=1,points={}};V.ShowZone(1);eq(focused,false);assert(A.status:find('Save',1,true));A[state]=nil
 end
end)
