local function setup()
 dofile('tests/wow.lua');fakeUI();local A={};for _,m in ipairs({'Store','Client','Map'}) do module(m,A) end
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Size=function() return 1000,500 end;A.Client.Distance=distance
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end
 LibStub=function() return {AddWorldMapIconMap=function() end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
 local nodes={};for i,id in ipairs({401,402}) do nodes[i]=A.Store.Observe(A.db,{mapID=1,x=.2+i*.002,y=.5,kind='herb',materialID='gm:herb:'..id,name=i==1 and 'Peacebloom' or 'Silverleaf',source='imported'}) end
 return A,nodes
end
test('overlapping map icons share one mixed badge while minimap outlines keep their exact spawns',function()
 local A,nodes=setup();A.Map.Refresh(A.db,nil);local world,mini=0,0;local badge
 for _,f in ipairs(A.Map.pins) do if f.key and f.group then if f.mini then mini=mini+1 else world=world+1;badge=f end end end
 eq(world,1);eq(mini,1);eq(badge.number:GetText(),'2');eq(badge.group.mixed,true)
 for _,n in ipairs(nodes) do local f=A.Map.byKey['m:node:'..n.key];assert(f and f.outline:IsShown());eq(f.icon:IsShown(),false);eq(f.signature,n.mapID..':'..n.x..':'..n.y) end
 local text={};GameTooltip.AddLine=function(_,s) text[#text+1]=s end;badge.scripts.OnEnter(badge);assert(table.concat(text):find('Silverleaf',1,true));assert(table.concat(text):find('Peacebloom',1,true))
 A.Selection.MarkerSettings(A.db.settings).materials={['gm:herb:401']=true};A.Map.Refresh(A.db,nil)
 for _,f in ipairs(A.Map.pins) do if f.key and f.group then error('Old mixed badge survived filtering') end end
 LibStub=nil;C_Minimap=nil
end)
test('world-map zoom splits groups and near-player grouped icons hide without hiding outlines',function()
 local A,nodes=setup();A.Map.Refresh(A.db,nil);WorldMapFrame.canvas.GetEffectiveScale=function() return 100 end
 A.Map.Refresh(A.db,nil);assert(A.Map.byKey['w:node:'..nodes[1].key]);assert(A.Map.byKey['w:node:'..nodes[2].key])
 A.Client.Position=function() return point(.2) end;A.Map.Refresh(A.db,nil)
 for _,f in ipairs(A.Map.pins) do if f.key and f.mini and f.group then eq(f.icon:IsShown(),false);eq(f.number:IsShown(),false);eq(f.mouseMotion,false) end end
 LibStub=nil;C_Minimap=nil
end)

test('grouped map refresh remains safe without a player zone or open world map',function()
 local A=setup();A.Client.Position=function() return nil end;WorldMapFrame:Hide();A.Map.Refresh(A.db,nil)
 LibStub=nil;C_Minimap=nil
end)

test('square minimap corner nodes remain visible when grouping is enabled',function()
 local A,nodes=setup();A.Client.Position=function() return point(.5,.5) end;A.db.nodes[1]={nodes[1]};nodes[1].x=.65;nodes[1].y=.2
 GetMinimapShape=function() return 'SQUARE' end;A.Map.Refresh(A.db,nil);assert(A.Map.byKey['m:node:'..nodes[1].key])
 GetMinimapShape=nil;LibStub=nil;C_Minimap=nil
end)

test('ignored minimap rotation places resource and destination rings in the same frame as heat clearance',function()
 local A,nodes=setup();module('Follower',A);A.Client.Position=function() return point(.5,.5) end;A.Client.Facing=function() return math.pi/2 end
 nodes[1].x=.6;nodes[1].y=.5;local ignored=true;local sdkAdds=0
 C_Minimap={GetViewRadius=function() return 200 end,IsRotateMinimapIgnored=function() return ignored end};GetCVar=function() return '1' end
 LibStub=function() return {AddWorldMapIconMap=function() end,RemoveWorldMapIcon=function() end,AddMinimapIconMap=function() sdkAdds=sdkAdds+1 end,RemoveMinimapIcon=function() end} end
 local create=CreateFrame;CreateFrame=function(...) local f=create(...);f.SetPoint=function(self,...) self.lastPoint={...} end;return f end
 local route={mapID=1,width=1000,height=500,points={point(.6,.5),point(.6,.2)}};local follower=A.Follower.New(route,point(.5,.5),distance)
 A.db.settings.routeStyle='heatmap';A.Map.Refresh(A.db,route,follower)
 local target=A.Map.byKey['m:point:1'];assert(target and target.lastPoint,'Destination needs an effective native projection');near(target.lastPoint[4],50);near(target.lastPoint[5],0);eq(sdkAdds,0)
 local resource=A.Map.byKey['m:node:'..nodes[1].key];near(resource.lastPoint[4],50);near(resource.lastPoint[5],0)
 for _,cell in ipairs(A.Map.miniHeatField) do assert(not (cell.x<=50 and cell.x+cell.width>=50 and cell.y>=0 and cell.y-cell.height<=0)) end
 Minimap.GetScale=function() return 1.5 end;A.Map.Refresh(A.db,route,follower);near(target.lastPoint[4],75);near(target.scale,2/3)
 A.Client.Position=function() return point(.52,.5) end;A.Map.nativeMiniPins.driver.scripts.OnUpdate(A.Map.nativeMiniPins.driver,.05);near(target.lastPoint[4],60)
 ignored=false;A.Map.Refresh(A.db,route,follower);assert(sdkAdds>0)
 LibStub=nil;C_Minimap=nil;GetCVar=nil
end)

test('minimap heat no longer punches a hole around every possible spawn',function()
 local A,nodes=setup();module('Follower',A)
 local route={mapID=1,width=1000,height=500,points={point(.2),point(.4)}};local f=A.Follower.New(route,point(.1),distance)
 A.db.settings.routeStyle='heatmap';local holes;local field=A.MiniHeat.Field
 A.MiniHeat.Field=function(r,p,w,h,s,input,...) holes=input;return field(r,p,w,h,s,input,...) end
 A.Map.Refresh(A.db,route,f);assert(holes and #holes<=2);assert(holes[1].r<=4)
 LibStub=nil;C_Minimap=nil
end)
