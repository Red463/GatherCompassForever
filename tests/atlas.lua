local function atlasSetup()
 local A={};for _,m in ipairs({'Store','Client','Resources','Atlas'}) do module(m,A) end
 A.db=A.Store.Open();return A
end
local function add(A,map,x,id,name,source,when)
 return A.Store.Observe(A.db,{mapID=map,x=x,y=.5,kind='herb',materialID=id,name=name,source=source or 'imported',time=when})
end
local function query(A,options,filter,player)
 local position=player or point(.1);if player==false then position=nil end
 return A.Atlas.Query(A.db,position,filter or {},options or {},{herb=109},{herb={maxRank=150,bonus=0}},distance)
end

test('atlas groups resource identities and keeps unique counts separate from personal gathers',function()
 local A=atlasSetup();local one=add(A,1,.2,'gm:herb:402','Silverleaf')
 add(A,1,.2,'gm:herb:402','Silverleaf','confirmed',100)
 add(A,1,.3,'node:herb:Silverleaf','Silverleaf')
 add(A,2,.4,'gm:herb:402','Silverleaf','confirmed',200)
 local result=query(A);eq(#result.groups,1);local g=result.groups[1]
 eq(g.count,2);eq(g.confirmed,1);eq(g.imported,2);eq(g.harvests,1);eq(g.lastGathered,100)
 eq(g.nearest.key,one.key);near(g.distance,100);eq(#g.currentNodes,2)
 eq(#g.zones,2);eq(g.zones[1].mapID,1);eq(g.zones[1].count,2)
 eq(g.materialIDs['gm:herb:402'],true);eq(g.materialIDs['node:herb:Silverleaf'],true)
 eq(query(A,{zone='all'}).groups[1].count,3)
end)

test('atlas applies scope source materials and meaningful skill filters without mutating choices',function()
 local A=atlasSetup();add(A,1,.2,'gm:herb:402','Silverleaf')
 add(A,1,.3,'gm:herb:403','Earthroot','confirmed',100)
 add(A,1,.4,'gm:herb:409','Wild Steelbloom');add(A,1,.5,'custom:herb','Mystery herb')
 add(A,2,.2,'gm:herb:403','Earthroot','confirmed',200)
 eq(#query(A,{skill='skillups'}).groups,1);eq(query(A,{skill='skillups'}).groups[1].name,'Earthroot')
 eq(#query(A,{skill='gatherable'}).groups,2);eq(#query(A,{zone=2}).groups,1)
 local filter={source='confirmed',kind='herb',materials={['gm:herb:403']=true}}
 local result=query(A,{zone='all'},filter);eq(#result.groups,1);eq(result.groups[1].count,2)
 eq(filter.source,'confirmed');eq(filter.materials['gm:herb:403'],true)
 eq(#query(A,{}, {kind='ore'}).groups,0)
end)

test('atlas sorts deterministically by distance difficulty harvests and recency with unknown distance last',function()
 local A=atlasSetup();add(A,1,.2,'gm:herb:402','Silverleaf','confirmed',10)
 add(A,1,.3,'gm:herb:403','Earthroot','confirmed',20);add(A,1,.3,'gm:herb:403','Earthroot','confirmed',30)
 add(A,2,.1,'gm:herb:405','Briarthorn')
 eq(query(A,{zone='all',sort='nearest'}).groups[1].name,'Silverleaf')
 eq(query(A,{zone='all',sort='difficulty'}).groups[1].name,'Briarthorn')
 eq(query(A,{sort='gathers'}).groups[1].name,'Earthroot');eq(query(A,{sort='recent'}).groups[1].name,'Earthroot')
 local result=A.Atlas.Query(A.db,nil,{}, {zone='all',sort='nearest'},{herb=109},{},nil)
 eq(result.groups[1].name,'Briarthorn');eq(result.groups[1].nearest,nil)
 eq(#query(A,{}, {},false).groups,0)
end)

test('atlas static index invalidates on node changes but not saved route updates',function()
 local A=atlasSetup();add(A,1,.2,'gm:herb:402','Silverleaf')
 local index=A.Atlas.Index(A.db);eq(A.Atlas.Index(A.db),index)
 A.Store.SaveRoute(A.db,{name='Route',mapID=1,points={point(.2)}});eq(A.Atlas.Index(A.db),index)
 add(A,1,.3,'gm:herb:403','Earthroot');assert(A.Atlas.Index(A.db)~=index)
 eq(#query(A).groups,2)
end)

test('atlas reuses scoped aggregates while refreshing distance and observing in-place filter changes',function()
 local A=atlasSetup();add(A,1,.2,'gm:herb:403','Earthroot');add(A,1,.8,'gm:herb:403','Earthroot')
 add(A,2,.4,'gm:herb:403','Earthroot');add(A,2,.5,'gm:herb:402','Silverleaf')
 local filter={materials={['gm:herb:403']=true,['gm:herb:402']=true}}
 local first=query(A,{zone='all'},filter);local earth=first.groups[1]
 local second=query(A,{zone='all'},filter,point(.9));local moved=second.groups[1]
 eq(moved.name,'Earthroot');eq(moved.zones,earth.zones);eq(moved.nodes,earth.nodes)
 assert(moved.nearest~=earth.nearest);near(earth.distance,100);near(moved.distance,100)
 eq(moved.locations[3],earth.locations[3])
 filter.materials['gm:herb:403']=false;eq(#query(A,{zone='all'},filter).groups,1)
 add(A,2,.6,'gm:herb:402','Silverleaf');eq(query(A,{zone='all'},filter).groups[1].count,2)
end)

test('atlas labels declared resource variants using their canonical group name',function()
 local A=atlasSetup()
 A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='ore',materialID='gm:ore:216',name='Ooze Covered Rich Thorium Vein',source='imported'})
 A.Store.Observe(A.db,{mapID=2,x=.3,y=.5,kind='ore',materialID='gm:ore:215',name='Rich Thorium Vein',source='imported'})
 local group=query(A,{zone='all'}).groups[1];eq(group.count,2);eq(group.name,'Rich Thorium Vein')
end)
