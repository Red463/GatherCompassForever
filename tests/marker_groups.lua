local function setup() local A={};module('Store',A);module('Resources',A);module('MarkerGroups',A);return A end
local function node(key,x,id) return {key=key,mapID=1,x=x,y=.5,kind='herb',materialID='gm:herb:'..(id or 401),name=id==402 and 'Silverleaf' or 'Peacebloom'} end
test('marker groups are stable mixed-resource screen clusters without changing spawn coordinates',function()
 local A=setup();local a,b,c=node('a',.1),node('b',.105,402),node('c',.5)
 local function project(n) return n.x*1000,n.y*500 end
 local groups=A.MarkerGroups.Build({c,b,a},project,14);eq(#groups,2);eq(#groups[1].members,2);eq(groups[1].mixed,true);eq(groups[1].anchor,a)
 eq(A.MarkerGroups.Build({a,b,c},project,14)[1].key,groups[1].key);eq(a.x,.1);eq(b.x,.105)
 eq(#A.MarkerGroups.Build({a,b,c},function(n) return n.x*10000,n.y*5000 end,14),3)
 eq(#A.MarkerGroups.Build({a,b},project,14,{disabled=true}),2)
end)
test('groups are radius bounded and preserve a focused member before applying the display cap',function()
 local A=setup();local nodes={};for i=1,100 do nodes[i]=node(string.format('%03d',i),i*.01) end
 local groups=A.MarkerGroups.Build(nodes,function(n) return n.x*1000,0 end,14,{limit=2,focus='100'})
 eq(#groups,2);eq(groups[1].anchor.key,'100')
 for _,g in ipairs(groups) do for _,n in ipairs(g.members) do assert(math.abs(n.x-g.anchor.x)*1000<=14) end end
end)
test('group work is bounded even for a dense twenty-thousand-node cell',function()
 local A=setup();local nodes={};for i=1,20000 do nodes[i]=node(tostring(i),.1+i*.00000001) end
 local groups=A.MarkerGroups.Build(nodes,function(n) return n.x*1000,0 end,14);eq(#groups,1);eq(#groups[1].members,20000)
 assert(groups.comparisons<100000);eq(#A.MarkerGroups.Build({},function() end,14),0)
end)

test('group icon represents the most common resource while keeping the geometry anchor',function()
 local A=setup();local a=node('a',.1,401);local b=node('b',.101,402);local c=node('c',.102,402)
 local function project(n) return n.x*1000,0 end
 local g=A.MarkerGroups.Build({c,a,b},project,14)[1]
 eq(g.anchor,a);eq(g.representative,b);eq(g.entries[1].count,2);eq(g.entries[2].count,1)
 local tied=A.MarkerGroups.Build({b,a},project,14,{focus='b'})[1];eq(tied.anchor,b);eq(tied.representative,a)
 eq(A.MarkerGroups.Build({a,b},project,14)[1].representative,a)
end)

test('group counts merge legacy and catalogue identities of the same resource',function()
 local A=setup();local a=node('a',.1,401);local b=node('b',.101,402);local old=node('c',.102,402);old.materialID='node:herb:Silverleaf'
 local g=A.MarkerGroups.Build({a,b,old},function(n) return n.x*1000,0 end,14)[1]
 eq(#g.entries,2);eq(g.entries[1].count,2);eq(g.representative,b)
end)
