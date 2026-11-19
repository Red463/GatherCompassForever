local function setup()
 dofile('tests/wow.lua');fakeUI();local A={};module('Store',A);module('MapArt',A);return A
end
test('map art uses UI map IDs and crops partial edge tiles in a shared projection',function()
 local A=setup();local ids={};local art=10
 C_Map={GetMapArtID=function(id) eq(id,1);return art end,GetMapArtLayers=function(id) eq(id,1);return {{layerWidth=1000,layerHeight=600,tileWidth=256,tileHeight=256}} end,
 GetMapArtLayerTextures=function(id,layer) eq(id,1);eq(layer,1);return {11,12,13,14,15,16,17,18,19,20,21,22} end}
 local v=A.MapArt.New(UIParent);local bounds={left=0,top=0,right=1,bottom=1};v:Draw(1,bounds,1000,600)
 eq(#v.tiles,12);local edge=v.tiles[12];eq(edge.texture,22);near(edge:GetWidth(),232);near(edge:GetHeight(),88);near(edge.coords[2],232/256);near(edge.coords[4],88/256)
 local x,y=A.MapArt.Project(point(.25,.5),bounds,1000,600);near(x,250);near(y,-300)
 C_Map.GetMapArtLayerTextures=function() return {99} end;art=11;v:Draw(1,bounds,1000,600);eq(v.tiles[1].texture,99);eq(v.tiles[2]:IsShown(),false)
 C_Map.GetMapArtLayers=nil;v:Draw(1,bounds,1000,600);eq(v.available,false);eq(v.tiles[1]:IsShown(),false)
end)

test('map art retries unavailable textures and clears the previous map aspect',function()
 local A=setup();local calls=0
 C_Map={GetMapArtID=function(id) return id end,GetMapArtLayers=function(id) if id==1 then return {{layerWidth=100,layerHeight=50,tileWidth=100,tileHeight=50}} end end,
 GetMapArtLayerTextures=function() calls=calls+1;if calls>1 then return {7} end;return {} end}
 local v=A.MapArt.New(UIParent);local b={left=0,top=0,right=1,bottom=1};v:Draw(1,b,400,200);eq(v.available,false)
 v:Draw(1,b,400,200);eq(v.available,true);eq(v.aspect,2);v:Draw(2,b,400,200);eq(v.aspect,nil)
 C_Map=nil
end)
test('zoomed map art clips tile geometry and UVs at the viewport edges',function()
 local A=setup();C_Map={GetMapArtID=function() return 1 end,GetMapArtLayers=function() return {{layerWidth=100,layerHeight=50,tileWidth=100,tileHeight=50}} end,GetMapArtLayerTextures=function() return {7} end}
 local v=A.MapArt.New(UIParent);v:Draw(1,{left=.25,top=.25,right=.75,bottom=.75},400,200)
 near(v.tiles[1]:GetWidth(),400);near(v.tiles[1]:GetHeight(),200);near(v.tiles[1].coords[1],.25);near(v.tiles[1].coords[2],.75)
 C_Map=nil
end)

test('revealed artwork adds missing exploration pieces with padded edge UVs and native overrides',function()
 local A=setup();A.MapReveal={[7]={['300:100:100:50']='91,92'}};local art=7;local explored={}
 C_Map={GetMapArtID=function() return art end,GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=600,tileWidth=256,tileHeight=256}} end,GetMapArtLayerTextures=function() return {1} end}
 C_MapExplorationInfo={GetExploredMapTextures=function(id) eq(id,1);return explored end}
 local v=A.MapArt.New(UIParent);local b={left=0,top=0,right=1,bottom=1};v:Draw(1,b,1000,600)
 eq(v.revealed,true);eq(#v.overlays,2);eq(v.overlays[2].texture,92);near(v.overlays[2].coords[2],44/64);near(v.overlays[2].coords[4],100/128)
 v:Draw(1,{left=.37,top=0,right=.39,bottom=.5},400,300);near(v.overlays[1].coords[1],14/64);near(v.overlays[1].coords[2],34/64);near(v.overlays[1]:GetWidth(),400)
 explored={{textureWidth=300,textureHeight=100,offsetX=100,offsetY=50,fileDataIDs={101,102}}, {textureWidth=20,textureHeight=20,offsetX=0,offsetY=0,fileDataIDs={103},isShownByMouseOver=true}}
 v.events.scripts.OnEvent(v.events,'MAP_EXPLORATION_UPDATED');v:Draw(1,b,1000,600);eq(v.overlays[1].texture,101);eq(v.overlays[2].texture,102);eq(#v.overlays,2)
 art=8;v:Draw(1,b,1000,600);eq(v.revealed,false);assert(v.status:find('Native',1,true));eq(v.overlays[1].texture,101)
 C_MapExplorationInfo=nil;C_Map=nil
end)

test('pinned reveal metadata includes only attributed map geometry and client texture IDs',function()
 local A={};module('Data/MapReveal',A);local maps,pieces=0,0
 for art,entries in pairs(A.MapReveal) do assert(type(art)=='number');maps=maps+1;for key,ids in pairs(entries) do assert(key:match('^%d+:%d+:%d+:%d+$'));assert(ids:match('^[%d,%s]+$'));pieces=pieces+1 end end
 eq(maps,84);eq(pieces,1073)
end)

test('incomplete native overlay files fall back to usable reveal metadata',function()
 local A=setup();A.MapReveal={[7]={['300:100:100:50']='91, 92'}}
 C_Map={GetMapArtID=function() return 7 end,GetMapArtLayers=function() return {{layerWidth=1000,layerHeight=600,tileWidth=256,tileHeight=256}} end,GetMapArtLayerTextures=function() return {1} end}
 C_MapExplorationInfo={GetExploredMapTextures=function() return {{textureWidth=300,textureHeight=100,offsetX=100,offsetY=50,fileDataIDs={101}}} end}
 local v=A.MapArt.New(UIParent);v:Draw(1,{left=0,top=0,right=1,bottom=1},1000,600);eq(#v.overlays,2);eq(v.overlays[2].texture,92)
 C_MapExplorationInfo=nil;C_Map=nil
end)

test('unavailable exploration after a phase change never revives the previous phase cache',function()
 local A=setup();local art=7;A.MapReveal={[7]={['20:20:0:0']='123'}}
 C_Map={GetMapArtID=function() return art end,GetMapArtLayers=function() return {{layerWidth=100,layerHeight=100,tileWidth=100,tileHeight=100}} end,GetMapArtLayerTextures=function() return {1} end}
 C_MapExplorationInfo={GetExploredMapTextures=function() if art==7 then return {} end end}
 local v=A.MapArt.New(UIParent);local b={left=0,top=0,right=1,bottom=1};v:Draw(1,b,100,100);eq(v.overlays[1].texture,123)
 art=8;v:Draw(1,b,100,100);eq(v.overlays[1]:IsShown(),false);v:Draw(1,b,100,100);eq(v.overlays[1]:IsShown(),false)
 C_MapExplorationInfo=nil;C_Map=nil
end)
