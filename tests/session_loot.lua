local function lootSession()
 local A={};for _,name in ipairs({'Store','SessionHistory','SessionLoot'}) do module(name,A) end
 local h=A.SessionHistory.New(A.Store.Open(),{key='Player-1-A'});local s=h:Begin({},100)
 local t=A.SessionLoot.New(h)
 local function e(slot,id,quantity) return {slot=slot,itemID=id,itemName='Item '..id,quantity=quantity,sourceGUID='GameObject-1'} end
 local function gather(cast) return {sessionID=s.id,castGUID=cast or 'cast1',sourceGUID='GameObject-1',kind='herb',source='confirmed',confirmedAt=1} end
 return A,h,s,t,e,gather
end

test('session loot counts cleared slots including bonuses once but not items left in the window',function()
 local A,h,s,t,e,g=lootSession();local rows={e(1,765,3),e(2,2452,2),e(3,2447,1)}
 t:Snapshot(rows,1);t:Snapshot(rows,1.1);t:Gather(g())
 eq(next(s.items),nil);t:Cleared(1,1.2);t:Cleared(1,1.3);t:Cleared(2,1.4);t:Closed(1.5)
 eq(s.items[765].quantity,3);eq(s.items[2452].quantity,2);eq(s.items[2447],nil);eq(s.gathers,1)
end)

test('loot cleared before cast confirmation is credited only after its source is confirmed',function()
 local A,h,s,t,e,g=lootSession();t:Snapshot({e(1,765,4)},1);t:Cleared(1,1.1);t:Closed(1.2)
 eq(next(s.items),nil);t:Gather(g());eq(s.items[765].quantity,4)
 t:Gather(g());eq(s.items[765].quantity,4);eq(s.gathers,1)
end)

test('successive mining casts from the same object count separate loot windows',function()
 local A,h,s,t,e,g=lootSession()
 for i=1,3 do
  t:Snapshot({e(1,2770,i)},i*3);local o=g('cast'..i);o.confirmedAt=i*3;o.kind='ore';t:Gather(o)
  t:Cleared(1,i*3+.1);t:Closed(i*3+.2)
 end
 eq(s.items[2770].quantity,6);eq(s.oreGathers,3)
end)

test('unconfirmed unrelated and old-session loot never enters a new route session',function()
 local A,h,s,t,e,g=lootSession();t:Snapshot({e(1,765,2)},1);t:Cleared(1,1.1)
 local wrong=g();wrong.sourceGUID='GameObject-other';t:Gather(wrong);eq(next(s.items),nil)
 h:Stop(110);local nextSession=h:Begin({},111);t:Gather(g());eq(next(nextSession.items),nil)
 t:Closed(2);t:Snapshot({e(1,765,99)},20);t:Cleared(1,20.1)
 local stale=g('late');stale.sessionID=nextSession.id;t:Gather(stale);eq(next(nextSession.items),nil)
end)

test('loot window receipt identities remain unique after reloading an open journal',function()
 local A,h,s,t,e,g=lootSession();t:Snapshot({e(1,765,2)},1);t:Gather(g());t:Cleared(1,1.1);t:Closed(2)
 local reloaded=A.SessionLoot.New(h);local o=g('afterReload');o.confirmedAt=3
 reloaded:Snapshot({e(1,765,3)},3);reloaded:Gather(o);reloaded:Cleared(1,3.1)
 eq(s.items[765].quantity,5)
end)

test('confirmed loot still counts when the player leaves the loot window open for a long time',function()
 local A,h,s,t,e,g=lootSession();t:Snapshot({e(1,765,3)},1);t:Gather(g())
 t:Cleared(1,90);eq(s.items[765].quantity,3)
end)
