test('missing importer is independent and malformed rows are skipped',function()
 local A={}; module('Store',A); module('Imports',A); A.Store.distance=distance; local db=A.Store.Open()
 local n,s=A.Imports.Scan(db); eq(n,0); assert(s:find('GatherMate2'))
 local rows={{mapID=1,x=.2,y=.3,kind='herb',materialID='item:2447',name='Peacebloom'},{mapID=1,x=99,y=0,kind='herb',materialID='bad'}}
 n=A.Imports.Scan(db,function() return ipairs(rows) end); eq(n,1)
 A.Imports.Scan(db,function() return ipairs(rows) end); eq(#db.nodes[1],1); eq(db.nodes[1][1].confirmed,nil)
end)
test('global provider discovers zones in GatherMate storage metadata without mutating them',function()
 local A={}; module('Store',A); module('Imports',A)
 local data={[42]={[2000300000]=401}}
 GatherMate2={gmdbs={['Herb Gathering']={__gm2_base_storage=data,__gm2_storage_map={extra={[43]={[3000400000]=401}}}}},
 GetNodesForZone=function(_,map) return pairs(data[map] or {[3000400000]=401}) end,
 DecodeLoc=function() return .2,.3 end,GetNameForNode=function() return 'Peacebloom' end}
 local provider=A.Imports.Provider();local db=A.Store.Open();local n=A.Imports.Scan(db,provider)
 eq(n,2); assert(db.nodes[42] and db.nodes[43]); eq(data[42][2000300000],401); GatherMate2=nil
end)
