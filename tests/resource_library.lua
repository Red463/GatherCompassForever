local function librarySetup()
 C_Item=nil;GetItemInfo=nil;GetItemIcon=nil;GatherMate2=nil
 local A={};for _,name in ipairs({'Store','Resources','Atlas','ResourceLibrary'}) do module(name,A) end
 A.db=A.Store.Open();return A
end
local function resource(A,id,kind,search)
 for _,item in ipairs(A.ResourceLibrary.Query(A.db,kind or 'all',search).items) do if item.itemID==id then return item end end
 error('Missing item '..tostring(id))
end
local function observe(A,map,x,id,name,kind,source,when)
 return A.Store.Observe(A.db,{mapID=map,x=x,y=.5,kind=kind or 'herb',materialID='gm:'..(kind or 'herb')..':'..id,name=name,source=source or 'imported',time=when})
end

test('resource library contains full item catalogue without nodes and separates item labels from veins',function()
 local A=librarySetup();assert(#A.ResourceLibrary.Query(A.db).items>35)
 local copper=resource(A,2770,'ore');eq(copper.name,'Copper Ore');eq(copper.count,0);eq(#copper.zones,0);eq(copper.sources[1].node.name,'Copper Vein')
 local silver=resource(A,765,'herb');eq(silver.name,'Silverleaf');assert(silver.icon)
 local rows=A.Resources.Catalog();rows[1].name='Changed';assert(A.Resources.Catalog()[1].name~='Changed')
 eq(#A.ResourceLibrary.Query(A.db,'herb','COPPER').items,0);eq(#A.ResourceLibrary.Query(A.db,'ore','copper').items,1)
 eq(#A.ResourceLibrary.Query(A.db,'all','%').items,0)
end)

test('resource library combines Thorium item locations while retaining separate vein requirements',function()
 local A=librarySetup()
 observe(A,1,.2,214,'Small Thorium Vein','ore');observe(A,1,.3,215,'Rich Thorium Vein','ore')
 observe(A,2,.4,216,'Ooze Covered Rich Thorium Vein','ore')
 local item=resource(A,10620,'ore');eq(item.name,'Thorium Ore');eq(item.count,3);eq(#item.sources,2)
 eq(item.sources[1].node.required,245);eq(item.sources[1].count,1);eq(item.sources[2].node.required,275);eq(item.sources[2].count,2)
 eq(item.materialIDs['gm:ore:214'],true);eq(item.materialIDs['gm:ore:216'],true)
 eq(item.zones[1].mapID,1);eq(item.zones[1].count,2);eq(item.zones[2].mapID,2)
end)

test('ranked zones count unique stored nodes with overlapping sources and distinct harvest interactions',function()
 local A=librarySetup();observe(A,2,.2,402,'Silverleaf');observe(A,2,.3,402,'Silverleaf')
 observe(A,1,.2,402,'Silverleaf');observe(A,1,.2,402,'Silverleaf',nil,'confirmed',100)
 observe(A,1,.2,402,'Silverleaf',nil,'confirmed',200);observe(A,3,.2,402,'Silverleaf')
 local item=resource(A,765);eq(item.count,4);eq(item.confirmed,1);eq(item.imported,4);eq(item.harvests,2);eq(item.lastGathered,200)
 eq(item.zones[1].mapID,2);eq(item.zones[2].mapID,1);eq(item.zones[3].mapID,3)
 eq(item.zones[2].confirmed,1);eq(item.zones[2].harvests,2)
end)

test('library caches static summaries and invalidates observations without following route filters',function()
 local A=librarySetup();observe(A,2,.2,402,'Silverleaf')
 A.db.settings.materials={};A.db.settings.kind='ore';A.db.settings.source='confirmed'
 local first=resource(A,765);eq(first.count,1);local second=resource(A,765);eq(first.zones,second.zones)
 observe(A,1,.3,402,'Silverleaf',nil,'confirmed',100);local third=resource(A,765)
 assert(third.zones~=first.zones);eq(third.count,2);eq(third.harvests,1)
 eq(A.db.settings.kind,'ore');eq(next(A.db.settings.materials),nil)
end)

test('library safely refreshes item labels and icons after client metadata becomes available',function()
 local A=librarySetup();local fallback=resource(A,2770);eq(fallback.name,'Copper Ore')
 C_Item={GetItemNameByID=function(id) if id==2770 then return 'Localized Copper' end end,GetItemIconByID=function() error('not cached') end}
 local loaded=resource(A,2770);eq(loaded.name,'Localized Copper');assert(loaded.icon);eq(loaded.zones,fallback.zones)
 C_Item={GetItemNameByID=function() error('unavailable') end};GetItemInfo=function() error('legacy unavailable') end
 eq(resource(A,2770).name,'Copper Ore');C_Item=nil;GetItemInfo=nil
end)

test('unknown saved resources stay browsable without fabricated item IDs or skills',function()
 local A=librarySetup();observe(A,4,.2,9999,'Forever Flower')
 local items=A.ResourceLibrary.Query(A.db,'herb','Forever Flower').items;eq(#items,1);eq(items[1].itemID,nil)
 eq(items[1].count,1);eq(items[1].name,'Forever Flower')
 eq(A.Resources.SkillDetails(items[1].sources[1].node,{}).key,'unknown')
 eq(A.Resources.ItemName({kind='herb',materialID='unknown',name=77}),'unknown')
end)
