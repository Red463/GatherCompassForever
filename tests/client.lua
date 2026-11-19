test('client rejects secret or unavailable map coordinates',function()
 local A={}; module('Store',A); module('Client',A)
 C_Map={GetBestMapForUnit=function() return 1 end,GetPlayerMapPosition=function() return {GetXY=function() return .2,.3 end} end,GetMapWorldSize=function() return 1000,500 end}
 eq(A.Client.Position().mapID,1); near(A.Client.Distance(point(.1),point(.2)),100)
 issecretvalue=function(v) return v==.2 end; eq(A.Client.Position(),nil); issecretvalue=nil
 C_Map=nil; eq(A.Client.Position(),nil); eq(A.Client.Probe().position,false)
end)

test('corridor range uses actual zoomed-out minimap radius without changing zoom',function()
 local A={};module('Store',A);module('Client',A)
 local oldMap,oldAPI=Minimap,C_Minimap;local zoom=0
 Minimap={GetZoom=function() return zoom end,SetZoom=function() error('Must not change user zoom') end}
 C_Minimap={GetViewRadius=function() return 240 end}
 local range=A.Client.CorridorRange();near(range.viewRadius,240);near(range.coverageRadius,216)
 zoom=1;local unavailable,reason=A.Client.CorridorRange();eq(unavailable,nil);assert(reason:find('fully out',1,true))
 zoom=0;C_Minimap.GetViewRadius=function() return 150 end;range=A.Client.CorridorRange();near(range.coverageRadius,135)
 Minimap,C_Minimap=oldMap,oldAPI
end)

test('corridor calibration rejects unreadable secret and invalid zoom or range data',function()
 local A={};module('Store',A);module('Client',A)
 local oldMap,oldAPI,oldSecret=Minimap,C_Minimap,issecretvalue
 Minimap={GetZoom=function() return 0 end};C_Minimap={GetViewRadius=function() return 200 end}
 for _,value in ipairs({-1,0/0,.5}) do Minimap.GetZoom=function() return value end;eq(A.Client.CorridorRange(),nil) end
 Minimap.GetZoom=function() error('blocked') end;eq(A.Client.CorridorRange(),nil)
 Minimap.GetZoom=function() return 0 end
 for _,value in ipairs({0,-2,math.huge,0/0}) do C_Minimap.GetViewRadius=function() return value end;eq(A.Client.CorridorRange(),nil) end
 C_Minimap.GetViewRadius=function() return 200 end;issecretvalue=function(v) return v==200 end;eq(A.Client.CorridorRange(),nil)
 issecretvalue=oldSecret;Minimap={};eq(A.Client.CorridorRange(),nil)
 Minimap={GetZoom=function() return 0 end};C_Minimap=nil;eq(A.Client.CorridorRange(),nil)
 Minimap,C_Minimap=oldMap,oldAPI
end)
