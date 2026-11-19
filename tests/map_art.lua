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
test('zoomed map art clips tile geometry and UVs at the viewport edges',function()
 local A=setup();C_Map={GetMapArtID=function() return 1 end,GetMapArtLayers=function() return {{layerWidth=100,layerHeight=50,tileWidth=100,tileHeight=50}} end,GetMapArtLayerTextures=function() return {7} end}
 local v=A.MapArt.New(UIParent);v:Draw(1,{left=.25,top=.25,right=.75,bottom=.75},400,200)
 near(v.tiles[1]:GetWidth(),400);near(v.tiles[1]:GetHeight(),200);near(v.tiles[1].coords[1],.25);near(v.tiles[1].coords[2],.75)
 C_Map=nil
end)
