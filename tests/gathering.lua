local function setup()
 local A={}; module('Store',A); module('Gathering',A); local out={}
 return A.Gathering.New(function(o) out[#out+1]=o end),out
end
local function attempt(id,t,x) local a=point(x or .2); a.castGUID=id; a.time=t or 0; a.kind='herb'; a.name='Peacebloom'; return a end
local function loot(id) return {sourceGUID='GameObject-0-0-0-0-1618-'..(id or '001'),objectID=1618,itemID=2447,itemName='Peacebloom',kind='herb',name='Peacebloom'} end
test('successful correlated cast and object loot confirms exactly once',function()
 local d,out=setup(); d:Sent(attempt('a')); d:Succeeded('a',2); d:Loot(loot(),2.1); d:Loot(loot(),2.2)
 eq(#out,1); eq(out[1].source,'confirmed'); eq(out[1].materialID,'item:2447')
end)
test('unrelated chest items delayed previous loot and multi source events cannot confirm',function()
 local d,out=setup(); d:Sent(attempt('a')); d:Succeeded('a',1)
 local chest=loot('chest'); chest.itemID=123; chest.itemName='Chest loot'; chest.kind=nil
 d:Loot(chest,1.1); eq(#out,0)
 d:Expire(12); d:Sent(attempt('b',12)); d:Succeeded('b',13); d:Loot(loot('late-a'),13.1); eq(#out,0)
 local e,out2=setup(); e:Sent(attempt('c')); e:Succeeded('c',1)
 local multiple=loot(); multiple.ambiguous=true; e:Loot(multiple,1); eq(#out2,0)
end)
test('bound source identity permits mining while foreign source cannot match',function()
 local d,out=setup(); local a=attempt('a'); a.kind='ore'; a.name='Copper Vein'; a.sourceGUID='GameObject-0-0-0-0-1731-001'
 d:Sent(a); d:Succeeded('a',1); d:Loot({sourceGUID='GameObject-0-0-0-0-1732-002',itemID=2771},1); eq(#out,0)
 d:Loot({sourceGUID=a.sourceGUID,itemID=2770},1.1); eq(#out,1)
end)
test('failed interrupted expired mismatched or loot only never confirms',function()
 local d,out=setup(); d:Loot(loot(),0); d:Sent(attempt('a')); d:Failed('a'); d:Succeeded('a',2); d:Loot(loot(),2)
 d:Sent(attempt('b',3)); d:Succeeded('wrong',4); d:Loot(loot(),4)
 d:Sent(attempt('c',5)); d:Succeeded('c',6); d:Expire(20); d:Loot(loot(),20); eq(#out,0)
end)
test('ambiguous overlapping casts and mismatched loot are not confirmed',function()
 local d,out=setup(); d:Sent(attempt('a')); d:Succeeded('a',1); d:Sent(attempt('b',1.1)); d:Succeeded('b',2); d:Loot(loot(),2); eq(#out,0)
 d:Expire(20); d:Sent(attempt('c',21)); d:Succeeded('c',22); local l=loot(); l.kind='ore'; d:Loot(l,22); eq(#out,0)
end)
test('loot can precede succeeded and is rejected without object source',function()
 local d,out=setup(); d:Sent(attempt('a')); d:Loot(loot(),1); d:Succeeded('a',1.1); eq(#out,1)
 d:Sent(attempt('b',3)); d:Succeeded('b',4); local l=loot(); l.sourceGUID='Creature-0-0'; d:Loot(l,4); eq(#out,1)
end)
