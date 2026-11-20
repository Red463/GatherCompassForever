test('production manifest loads supplied terrain and uses it for queued generation and guidance',function()
 dofile('tests/wow.lua');fakeUI();GatherlyDB=nil;local A={};local player={mapID=1440,x=.4,y=.55}
 C_Map={GetBestMapForUnit=function() return 1440 end,GetPlayerMapPosition=function() return {GetXY=function() return player.x,player.y end} end,GetMapWorldSize=function() return 5766.6664,3843.7499 end,GetMapInfo=function() return {name='Ashenvale'} end}
 C_Minimap={GetViewRadius=function() return 200 end};GetTime=function() return 0 end;GetPlayerFacing=function() return 0 end
 LibStub=nil;GatherMate2=nil
 for line in io.lines('Gatherly.toc') do
  if line~='' and line:sub(1,1)~='#' and line:sub(1,5)~='Libs/' then module(line:gsub('%.lua$',''),A) end
 end
 assert(A.Terrain and A.TerrainData and A.PlanningJob)
 player=assert(A.Terrain.Approach(player,30));A.Client.Position=function() return player end
 A.OnEvent(nil,'ADDON_LOADED','Gatherly');assert(A.initialized)
 for i=0,2 do
  local p=assert(A.Terrain.Approach({mapID=1440,x=player.x+i*.002,y=player.y},30))
  p.kind='herb';p.materialID='gm:herb:404';p.name='Mageroyal';p.source='imported';A.Store.Observe(A.db,p)
 end
 A.UI.OpenRoutes();A.UI.actions.generateStart();eq(A.follower,nil)
 for _=1,500 do A.Tick(1/60);if A.follower then break end end
 assert(A.follower,tostring(A.status));eq(A.follower.status,'running');eq(A.follower.route.terrainVersion,1)
 assert(A.Terrain.Validate(A.follower.route));assert(A.Terrain.Segment(player,A.follower:Target()))
 local follower=A.follower;local direction=follower.direction
 A.Command('trace');eq(A.GuidanceTrace.active,true);A.Tick(.1)
 A.Client.Position=function() return nil,'coordinates-protected' end;A.Tick(.1)
 local events=A.db.guidanceTrace.events;eq(events[#events].event,'dropout');eq(events[#events].positionReason,'coordinates-protected')
 A.Client.Position=function() return player end;GetTime=function() return 2 end;A.Tick(2)
 eq(events[#events].event,'recovered');eq(A.follower,follower);eq(follower.direction,direction)
 GetPlayerFacing=function() return nil end;A.Tick(.1)
 eq(follower.status,'running');eq(A.Arrow.frame.icon:IsShown(),false)
 eq(events[#events].event,'arrow-unavailable');eq(events[#events].cause,'facing-unavailable')
 GetPlayerFacing=function() return 0 end;A.Tick(.1)
 eq(events[#events].event,'arrow-restored');assert(A.Arrow.frame.icon:IsShown())
 -- Opening the copyable report freezes the history without changing guidance.
 A.Command('trace report');eq(A.GuidanceTrace.active,false);assert(A.GuidanceTrace.frame:IsShown())
 assert(A.GuidanceTrace.frame.edit:GetText():find('coordinates-protected',1,true));eq(A.follower,follower)
 A.Command('trace');eq(A.GuidanceTrace.frame:IsShown(),false);A.Command('trace off');eq(A.GuidanceTrace.active,false)
 A.UI.actions.stop();eq(A.follower,nil)
end)
