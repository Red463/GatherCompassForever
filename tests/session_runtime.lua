local function runtimeSession()
 local A={};for _,name in ipairs({'Store','Client','Gathering','SessionHistory','SessionLoot','Core'}) do module(name,A) end
 A.UI={Build=function() return true end,Refresh=function() end};A.Arrow={Build=function() end};A.MinimapButton={Build=function() end}
 A.Client.Character=function() return {key='Player-session-test',name='Tom',realm='Realm'} end
 A.Client.Timestamp=function() return 100 end;A.Client.Now=function() return 1 end
 A.Client.Attempt=function(_,cast)
  return {mapID=1440,x=.2,y=.3,castGUID=cast,kind='herb',name='Silverleaf',materialID='gm:herb:402',time=0,sourceGUID='GameObject-1'}
 end
 local old=GatherlyDB;GatherlyDB=nil;A.Initialize();GatherlyDB=old
 return A
end

test('core records received detour loot while guidance is paused or already completed',function()
 for _,status in ipairs({'paused','complete'}) do
  local A=runtimeSession();assert(A.sessions);local active=A.sessions:Begin({name='Herbs',mapID=1440},100)
  A.follower={status=status,runID=1,lap=9,ConfirmGather=function() end}
  A.Client.LootEvidence=function() return {
   {slot=1,itemID=765,itemName='Silverleaf',quantity=3,sourceGUID='GameObject-1'},
   {slot=2,itemID=2452,itemName='Swiftthistle',quantity=1,sourceGUID='GameObject-1'}} end
  A.OnEvent(nil,'UNIT_SPELLCAST_SENT','player','Silverleaf','cast1',2366)
  A.OnEvent(nil,'UNIT_SPELLCAST_SUCCEEDED','player','cast1')
  A.OnEvent(nil,'LOOT_READY');A.OnEvent(nil,'LOOT_OPENED')
  eq(next(active.items),nil);A.OnEvent(nil,'LOOT_SLOT_CLEARED',1);A.OnEvent(nil,'LOOT_SLOT_CLEARED',2)
  eq(active.items[765].quantity,3);eq(active.items[2452].quantity,1);eq(active.gathers,1)
  A.OnEvent(nil,'LOOT_CLOSED');eq(A.sessions:Active(),active)
 end
end)

test('published routes share one session until Stop even after replacing guidance',function()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Editor','Planner','Follower','SessionHistory'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open();A.sessions=A.SessionHistory.New(A.db,{key='Player-1-A'})
 A.Client.Timestamp=function() return 100 end;A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
 A.UI.Build();A.UI.OpenRoutes();A.UI.actions.generateReview();eq(A.sessions:Active(),nil)
 A.UI.actions.start();local active=A.sessions:Active();assert(active)
 A.UI.actions.generateStart();eq(A.sessions:Active(),active);eq(#A.sessions:List(),0)
 local shown;A.UI.OpenHistory=function(id) shown=id end;A.Client.Timestamp=function() return 145 end
 A.UI.actions.stop();eq(A.sessions:Active(),nil);eq(#A.sessions:List(),1);eq(shown,active.id);eq(A.sessions:List()[1].duration,45)
 A.UI.actions.stop();eq(#A.sessions:List(),1)
end)

test('client loot evidence preserves quantities and slot identity needed for received item tracking',function()
 local A={};module('Store',A);module('Client',A)
 local oldNum,oldSource,oldLink=GetNumLootItems,GetLootSourceInfo,GetLootSlotLink
 GetNumLootItems=function() return 2 end
 GetLootSourceInfo=function(slot) return 'GameObject-0-0-0-0-1618-123',slot+1 end
 GetLootSlotLink=function(slot) return '|Hitem:'..(slot==1 and 765 or 2452)..'|h[Herb]|h' end
 local rows=A.Client.LootEvidence();eq(rows[1].slot,1);eq(rows[1].quantity,2);eq(rows[2].quantity,3);eq(rows[2].itemID,2452)
 GetNumLootItems,GetLootSourceInfo,GetLootSlotLink=oldNum,oldSource,oldLink
end)
