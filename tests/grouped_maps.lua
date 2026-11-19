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
 A.db.settings.materials={['gm:herb:401']=true};A.Map.Refresh(A.db,nil)
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
