test('client rejects secret or unavailable map coordinates',function()
 local A={}; module('Store',A); module('Client',A)
 C_Map={GetBestMapForUnit=function() return 1 end,GetPlayerMapPosition=function() return {GetXY=function() return .2,.3 end} end,GetMapWorldSize=function() return 1000,500 end}
 eq(A.Client.Position().mapID,1); near(A.Client.Distance(point(.1),point(.2)),100)
 issecretvalue=function(v) return v==.2 end; eq(A.Client.Position(),nil); issecretvalue=nil
 C_Map=nil; eq(A.Client.Position(),nil); eq(A.Client.Probe().position,false)
end)
