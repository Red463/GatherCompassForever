local function setup()
 dofile('tests/wow.lua');fakeUI();local A={};for _,m in ipairs({'Store','Client','Planner','Follower'}) do module(m,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.3) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance;A.Client.Probe=function() return {loot=true,facing=true,distance=true,minimap=true} end
 A.UI.Build();A.UI.OpenRoutes();A.UI.SetTab('codex');return A,A.UI.codexView
end
test('Codex scrolling reaches a large catalogue with bounded recycled tiles and no pages',function()
 local A,v=setup();for i=1,300 do A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='herb',materialID='node:herb:Custom '..i,name='Custom '..i,source='confirmed'}) end
 A.UI.Refresh();assert(v.gridList);eq(A.UI.controls.resourceNext,nil);eq(A.UI.controls.resourcePrev,nil)
 local seen={};for offset=0,v.gridList.scroller.maximum+v.gridList.height,v.gridList.height do v.gridList:SetOffset(offset);for _,b in ipairs(v.tiles) do if b.item and b:IsVisible() then seen[b.item.id]=true end end end
 local count=0;for _ in pairs(seen) do count=count+1 end;eq(count,#v.model.items);assert(#v.tiles<80)
end)
test('Codex Back preserves scroll while a new query resets it and recycled tiles change targets',function()
 local A,v=setup();v.gridList:SetOffset(150);local offset=v.gridList.scroller.offset;local id=v.tiles[1].item.id
 v.Open(id);v.Back();eq(v.gridList.scroller.offset,offset)
 v.gridList:SetOffset(0);assert(v.tiles[1].item.id~=id);v.SetSearch('Silverleaf');eq(v.gridList.scroller.offset,0);eq(v.tiles[1].item.name,'Silverleaf')
end)
test('ranked zone list scrolls to every zone and recycled clicks use their current binding',function()
 local A,v=setup();for map=1,40 do A.Store.Observe(A.db,{mapID=map,x=.2,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'}) end
 v.SetSearch('Silverleaf');v.Open(v.tiles[1].item.id);assert(v.zoneList);eq(A.UI.controls.resourceZoneNext,nil)
 v.zoneList:SetOffset(10000);local last=false;for _,row in ipairs(v.zoneRows) do if row.zone and row.zone.mapID==40 then last=true end end;assert(last);assert(#v.zoneRows<20)
 local selected;v.ShowZone=function(id) selected=id end;local row=v.zoneRows[1];row.scripts.OnClick(row);eq(selected,row.zone.mapID)
end)
