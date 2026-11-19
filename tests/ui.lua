test('UI source kind and material controls affect actual node selection',function()
 dofile('tests/wow.lua'); fakeUI(); local A={}; module('Store',A); module('Client',A); module('Editor',A); moduleUI(A)
 A.db=A.Store.Open(); A.Store.distance=distance; A.Client.Position=function() return point(.1) end
 A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='herb',materialID='a',source='confirmed',name='A'})
 A.Store.Observe(A.db,{mapID=1,x=.3,y=.5,kind='ore',materialID='b',source='imported',name='B'})
 A.UI.Build(); eq(#A.UI.SelectedNodes(),2)
 A.UI.SetSource('confirmed'); eq(#A.UI.SelectedNodes(),1)
 A.UI.SetSource('combined'); A.UI.SetKind('ore'); eq(#A.UI.SelectedNodes(),1)
 A.UI.SetKind('both'); A.UI.ToggleMaterial('a'); eq(#A.UI.SelectedNodes(),1); eq(A.UI.SelectedNodes()[1].materialID,'b')
end)

test('material skill colours survive hover selection and scrolling then refresh rank cap and bonus',function()
 dofile('tests/wow.lua');fakeUI();local A={};module('Store',A);module('Client',A);moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end
 local rank,cap,bonus=109,150,0
 A.Resources.Skills=function() return {herb=rank},{herb={maxRank=cap,bonus=bonus}} end
 for i,item in ipairs({{403,'Earthroot'},{401,'Peacebloom'},{402,'Silverleaf'},{409,'Wild Steelbloom'},{405,'Briarthorn'}}) do
  A.Store.Observe(A.db,{mapID=1,x=.2+i*.1,y=.5,kind='herb',materialID='gm:herb:'..item[1],name=item[2],source='imported'})
 end
 A.UI.Build();A.UI.OpenRoutes()
 local function row(name) for _,r in ipairs(A.UI.materialRows) do if r:IsShown() and r.materialName==name then return r end end;error('Missing material '..name) end
 local function colour(r,key) for i=1,3 do near(r.label.textColor[i],A.Resources.colors[key][i]) end end
 local earth=row('Earthroot');colour(earth,'green');colour(row('Peacebloom'),'grey');colour(row('Briarthorn'),'yellow')
 earth.scripts.OnEnter(earth);colour(earth,'green');earth.scripts.OnMouseDown(earth,'LeftButton');colour(earth,'green')
 earth.scripts.OnMouseUp(earth);earth.scripts.OnLeave(earth);colour(earth,'green')
 earth.scripts.OnClick(earth);eq(earth.check:IsShown(),false);colour(earth,'green')
 rank,cap=75,75;A.UI.Refresh();colour(row('Earthroot'),'grey')
 A.UI.filterSidebar:SetOffset(A.UI.filterSidebar.maximum);colour(row('Wild Steelbloom'),'red')
 rank,cap,bonus=110,150,5;A.UI.Refresh();colour(row('Wild Steelbloom'),'orange')
 rank=nil;A.UI.Refresh();colour(row('Wild Steelbloom'),'unknown')
 local tooltip={};GameTooltip.SetText=function(_,value) tooltip={value} end;GameTooltip.AddLine=function(_,value) tooltip[#tooltip+1]=value end
 row('Wild Steelbloom').scripts.OnEnter(row('Wild Steelbloom'))
 assert(table.concat(tooltip,'\n'):find('Skill-up chance unknown',1,true))
end)
test('editor loop reverse save and recording save discard controls are wired',function()
 dofile('tests/wow.lua'); fakeUI(); local A={}; module('Store',A); module('Client',A); module('Editor',A); moduleUI(A)
 A.db=A.Store.Open(); A.Client.Position=function() return point(.1) end
 A.UI.Build(); A.editor=A.Editor.New({name='Trail',mapID=1,points={point(.1),point(.2)},loop=false})
 A.UI.controls.loop.scripts.OnClick(); eq(A.editor:Route().loop,true)
 A.UI.controls.reverse.scripts.OnClick(); near(A.editor:Route().points[1].x,.2)
 A.UI.name:SetText('Saved'); A.UI.controls.save.scripts.OnClick(); eq(A.db.routes[A.selectedRoute].name,'Saved')
 A.recordedDraft={name='Recorded',mapID=1,points={point(.3)}}; A.UI.controls.discardRecording.scripts.OnClick(); eq(A.recordedDraft,nil)
 A.recordedDraft={name='Recorded',mapID=1,points={point(.3)}}; A.UI.controls.saveRecording.scripts.OnClick(); assert(A.selectedRoute); eq(A.recordedDraft,nil)
end)
