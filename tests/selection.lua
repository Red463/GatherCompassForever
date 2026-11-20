local function setup()
 local A={};for _,name in ipairs({'Store','Client','Resources','Selection'}) do module(name,A) end
 A.db=A.Store.Open();return A
end
test('checkbox source and type unions preserve legacy filters and explicit empty selections',function()
 local A=setup();local M=A.Selection;local s=A.db.settings
 eq(M.Filter(s).source,'combined');eq(M.Filter(s).kind,'both')
 M.ToggleSource(s,'confirmed');eq(s.source,'imported');M.ToggleSource(s,'imported');eq(s.source,'none')
 M.ToggleKind(s,'herb');eq(s.kind,'ore');M.ToggleKind(s,'ore');eq(s.kind,'none')
 local saved=A.Store.Open(A.Store.Copy(A.db));eq(M.Filter(saved.settings).source,'none');eq(M.Filter(saved.settings).kind,'none')
 M.ToggleSource(s,'confirmed');eq(s.source,'confirmed');M.ToggleSource(s,'imported');eq(s.source,'combined')
 M.ToggleKind(s,'herb');eq(s.kind,'herb');M.ToggleKind(s,'ore');eq(s.kind,'both')
 for _,v in ipairs({'confirmed','imported','combined','none'}) do s.source=v;eq(M.Filter(s).source,v) end
end)
test('shared selections intersect source type and material without duplicating dual provenance',function()
 local A=setup();local S=A.Store;local M=A.Selection
 local a={mapID=1,x=.2,y=.5,kind='herb',materialID='a',source='imported'};S.Observe(A.db,a);a.source='confirmed';S.Observe(A.db,a)
 S.Observe(A.db,{mapID=1,x=.3,y=.5,kind='ore',materialID='b',source='imported'})
 eq(#S.Select(A.db,1,M.Filter(A.db.settings)),2)
 A.db.settings.source='confirmed';eq(#S.Select(A.db,1,M.Filter(A.db.settings)),1)
 A.db.settings.materials={b=true};eq(#S.Select(A.db,1,M.Filter(A.db.settings)),0)
 A.db.settings.source='combined';eq(#S.Select(A.db,1,M.Filter(A.db.settings)),1)
 local choices=M.Materials(A.db,1,A.db.settings);eq(#choices,2)
 eq(choices,M.Materials(A.db,1,A.db.settings))
 S.Observe(A.db,{mapID=1,x=.4,y=.5,kind='herb',materialID='c',source='confirmed'});eq(#M.Materials(A.db,1,A.db.settings),3)
end)

test('material choices tolerate missing or malformed display names',function()
 local A=setup();A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='custom',name={},source='imported'})
 eq(A.Selection.Materials(A.db,1,A.db.settings)[1].name,'custom')
end)
test('bulk skill-up selection covers all zones once and allows later manual changes',function()
 local A=setup();local M=A.Selection;local db=A.db
 for i,row in ipairs({{1,403,'Earthroot'},{2,405,'Briarthorn'},{1,401,'Peacebloom'},{1,409,'Wild Steelbloom'},{2,9999,'Unknown'}}) do
  A.Store.Observe(db,{mapID=row[1],x=.1+i*.1,y=.5,kind='herb',materialID='gm:herb:'..row[2],name=row[3],source='imported'})
 end
 M.Bulk(db,'skillups',true,{herb=109},{herb={maxRank=150,bonus=0}})
 eq(db.settings.materials['gm:herb:403'],true);eq(db.settings.materials['gm:herb:405'],true)
 eq(db.settings.materials['gm:herb:401'],nil);eq(db.settings.materials['gm:herb:409'],nil);eq(db.settings.materials['gm:herb:9999'],nil)
 local state=M.BulkState(db,{herb=109},{herb={maxRank=150,bonus=0}});eq(state.skillups,true);eq(state.selected,2);eq(state.total,5)
 M.BulkState(db,{herb=150},{herb={maxRank=150}});eq(db.settings.materials['gm:herb:403'],true)
 M.ToggleMaterial(db,'gm:herb:401');eq(db.settings.materials['gm:herb:401'],true)
 M.Bulk(db,'all',true);eq(db.settings.materials,nil);M.ToggleMaterial(db,'gm:herb:401');eq(db.settings.materials['gm:herb:401'],false);eq(db.settings.materials['gm:herb:405'],true)
 M.Bulk(db,'all',false);eq(next(db.settings.materials),nil)
 M.Bulk(db,'skillups',true,{},{});eq(next(db.settings.materials),nil)
end)

test('Gatherable bulk includes grey and capped resources with readable requirements and excludes unknown or too difficult',function()
 local A=setup();local M=A.Selection
 for _,row in ipairs({{401,'Peacebloom'},{403,'Earthroot'},{409,'Wild Steelbloom'},{9999,'Unknown'}}) do
  A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:'..row[1],name=row[2],source='imported'})
 end
 M.Bulk(A.db,'gatherable',true,{herb=109},{herb={maxRank=150,bonus=0}})
 eq(A.db.settings.materials['gm:herb:401'],true);eq(A.db.settings.materials['gm:herb:403'],true)
 eq(A.db.settings.materials['gm:herb:409'],nil);eq(A.db.settings.materials['gm:herb:9999'],nil)
 eq(M.BulkState(A.db,{herb=109},{herb={maxRank=150,bonus=0}}).gatherable,true)
 M.Bulk(A.db,'gatherable',true,{herb=109},{herb={maxRank=109,bonus=10}});eq(A.db.settings.materials['gm:herb:409'],true)
 M.ToggleMaterial(A.db,'gm:herb:401');eq(A.db.settings.materials['gm:herb:401'],false)
 M.Bulk(A.db,'gatherable',true,{},{});eq(next(A.db.settings.materials),nil)
end)

test('starter nodes remain skill-up route targets through skill 100 and leave at 101',function()
 local A=setup();local M=A.Selection
 A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 M.Bulk(A.db,'skillups',true,{herb=100},{herb={maxRank=150,bonus=0}})
 eq(A.db.settings.materials['gm:herb:401'],true)
 M.Bulk(A.db,'skillups',true,{herb=101},{herb={maxRank=150,bonus=0}})
 eq(A.db.settings.materials['gm:herb:401'],nil)
 M.Bulk(A.db,'gatherable',true,{herb=101},{herb={maxRank=150,bonus=0}})
 eq(A.db.settings.materials['gm:herb:401'],true)
end)
