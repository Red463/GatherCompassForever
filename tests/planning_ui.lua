local function planningUI()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Editor','Planner','Follower','PlanningJob','SessionHistory'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open();A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.Store.Observe(A.db,{mapID=1,x=.2,y=.5,kind='herb',materialID='gm:herb:402',name='Silverleaf',source='imported'})
 A.UI.Build();A.UI.OpenRoutes();return A,A.UI
end

test('queued planning is obvious immediately and clears on completion',function()
 local A,U=planningUI();local done=0
 A.PlanJob(function() coroutine.yield();return true end,function() done=done+1 end)
 assert(A.PlanningJob.IsRunning());assert(U.planningOverlay:IsShown());eq(U.controls.generateStart:IsEnabled(),false)
 eq(U.controls.generateStart:GetText(),'Generating...');assert(U.planningTitle:GetText():find('Generating route',1,true))
 A.PlanningJob.Tick();assert(U.planningOverlay:IsShown());eq(done,0)
 A.PlanningJob.Tick();eq(done,1);eq(A.PlanningJob.IsRunning(),false);eq(U.planningOverlay:IsShown(),false)
 eq(U.controls.generateStart:IsEnabled(),true);eq(U.controls.generateStart:GetText(),'Generate & start')
end)

test('cancelling planning preserves the active follower and gathering session',function()
 local A,U=planningUI();local f=A.Follower.New({mapID=1,points={point(.2)}},point(.1),distance);A.follower=f
 A.sessions=A.SessionHistory.New(A.db,{key='Realm:Tom'});local session=A.sessions:Begin({name='Existing route'},100)
 local published=false;A.PlanJob(function() coroutine.yield() end,function() published=true end)
 U.controls.cancelPlanning.scripts.OnClick();A.PlanningJob.Tick()
 eq(published,false);eq(A.PlanningJob.IsRunning(),false);eq(U.planningOverlay:IsShown(),false)
 eq(A.follower,f);eq(A.sessions:Active(),session);eq(#A.sessions:List(),0)
end)

test('planning display clears on failure and zone cancellation and fits each window preset',function()
 local A,U=planningUI()
 for _,preset in ipairs({'small','standard','large'}) do
  U.window:SetPreset(preset);A.PlanJob(function() coroutine.yield() end);U.Refresh()
  assert(U.planningCard:GetWidth()<=U.body:GetWidth());assert(U.planningCard:GetHeight()<=U.body:GetHeight())
  U.SetTab('settings');assert(U.planningOverlay:IsShown());A.PlanningJob.Cancel()
 end
 U.OpenRoutes();A.PlanJob(function() error('Test planning failure') end);A.PlanningJob.Tick();eq(U.planningOverlay:IsShown(),false)
 A.PlanJob(function() coroutine.yield() end);A.Client.Position=function() return {mapID=2,x=.1,y=.5} end
 A.PlanningJob.Tick();eq(U.planningOverlay:IsShown(),false);eq(A.PlanningJob.IsRunning(),false)
end)

test('route generation shows busy state through the real action and clears even if the window is hidden',function()
 local A,U=planningUI();U.actions.generateReview();assert(U.planningOverlay:IsShown());eq(A.plan,nil)
 U.SetCompact(true);assert(U.footerMeta:GetText():find('Generating route',1,true));U.frame:Hide()
 for _=1,100 do A.PlanningJob.Tick();if not A.PlanningJob.IsRunning() then break end end
 assert(A.plan);eq(U.planningOverlay:IsShown(),false)
 U.OpenRoutes();eq(U.controls.generateStart:IsEnabled(),true)
end)
