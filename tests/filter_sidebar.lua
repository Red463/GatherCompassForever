local function setup()
 dofile('tests/wow.lua');fakeUI();local A={};for _,name in ipairs({'Store','Client','Editor','Follower'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.Resources.Skills=function() return {herb=109},{herb={maxRank=150,bonus=0}} end
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end
test('sidebar source and gathering checkboxes can combine or clear independently',function()
 local A,U=setup();assert(U.filterSidebar)
 for _,key in ipairs({'sourceConfirmed','sourceImported','kindHerb','kindOre','allMaterials','skillMaterials','gatherableMaterials'}) do eq(U.controls[key].kind,'CheckButton') end
 eq(U.controls.source,nil);eq(U.controls.kind,nil);eq(U.controls.prevMaterials,nil);eq(U.controls.nextMaterials,nil)
 U.controls.sourceConfirmed.scripts.OnClick();eq(A.db.settings.source,'imported')
 U.controls.sourceImported.scripts.OnClick();eq(A.db.settings.source,'none');eq(U.controls.sourceConfirmed:GetChecked(),false)
 U.controls.kindHerb.scripts.OnClick();U.controls.kindOre.scripts.OnClick();eq(A.db.settings.kind,'none')
 U.controls.sourceConfirmed.scripts.OnClick();U.controls.kindHerb.scripts.OnClick();eq(A.db.settings.source,'confirmed');eq(A.db.settings.kind,'herb')
end)
test('material scrollbar reaches the last row and preserves then clamps its offset',function()
 local A,U=setup()
 for i=1,24 do A.Store.Observe(A.db,{mapID=1,x=.01*i,y=.5,kind='herb',materialID='m'..i,name=string.format('Material %02d',i),source='imported'}) end
 U.Refresh();local view=U.filterSidebar;eq(view.scroll.kind,'ScrollFrame');eq(view.scroll:GetScrollChild(),view.child)
 eq(#view.rows,24);assert(view.maximum>0);view.scroll.scripts.OnMouseWheel(view.scroll,-100);eq(view.offset,view.maximum)
 local offset=view.offset;view.rows[24].scripts.OnClick(view.rows[24]);eq(A.db.settings.materials.m24,false);eq(view.offset,offset)
 U.Refresh();eq(view.offset,offset);U.SetSource('confirmed');eq(view.maximum,0);eq(view.offset,0);eq(view.empty:IsShown(),true)
end)

test('unavailable current position does not expose another zone materials while All zones remains explicit',function()
 local A,U=setup();A.Store.Observe(A.db,{mapID=2,x=.3,y=.5,kind='herb',materialID='gm:herb:401',name='Peacebloom',source='imported'})
 A.Client.Position=function() return nil end;U.Refresh()
 for _,row in ipairs(U.materialRows) do eq(row.materialID,nil) end
 eq(U.filterSidebar.empty:IsShown(),true);assert(U.filterSidebar.empty:GetText():find('Position unavailable',1,true))
 U.SetTab('codex');U.codexView.SetSearch('Peacebloom');eq(U.codexView.model.items[1].count,1);eq(U.sidebar:IsShown(),false)
end)
test('bulk material checkboxes include offscreen and other-zone materials then allow edits',function()
 local A,U=setup()
 for _,row in ipairs({{1,403,'Earthroot'},{2,405,'Briarthorn'},{1,401,'Peacebloom'},{1,409,'Wild Steelbloom'}}) do
  A.Store.Observe(A.db,{mapID=row[1],x=.3,y=.5,kind='herb',materialID='gm:herb:'..row[2],name=row[3],source='imported'})
 end
 U.Refresh();U.controls.allMaterials.scripts.OnClick();eq(next(A.db.settings.materials),nil)
 U.controls.skillMaterials.scripts.OnClick();eq(A.db.settings.materials['gm:herb:403'],true);eq(A.db.settings.materials['gm:herb:405'],true);eq(A.db.settings.materials['gm:herb:401'],nil)
 eq(U.controls.skillMaterials:GetChecked(),true);U.ToggleMaterial('gm:herb:401');eq(U.controls.skillMaterials:GetChecked(),false)
 U.controls.allMaterials.scripts.OnClick();eq(A.db.settings.materials,nil)
end)
test('changing shared filters preserves running guidance and editor drafts',function()
 local A,U=setup();local route={name='Keep',mapID=1,loop=true,points={point(.3),point(.5)}}
 A.follower=A.Follower.New(route,point(.1),distance);local follower=A.follower;local target=follower:Target()
 U.controls.sourceImported.scripts.OnClick();U.controls.kindOre.scripts.OnClick();eq(A.follower,follower);eq(follower:Target(),target)
 A.follower=nil;U.Edit(route);local editor=A.editor;U.ToggleMaterial('m');eq(A.editor,editor);eq(#editor.draft.points,2)
end)
