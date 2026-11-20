local function historyUI()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Editor','Planner','Follower','SessionHistory'}) do module(name,A) end;moduleUI(A)
 A.db=A.Store.Open();A.sessions=A.SessionHistory.New(A.db,{key='Player-1-A',name='Tom',realm='Realm'})
 A.Client.Timestamp=function() return 100 end;A.Client.Position=function() return point(.1) end;A.Client.Distance=distance;A.Client.Size=function() return 1000,500 end
 A.UI.Build();return A,A.UI
end

test('History shows newest-first character sessions and reopens the same saved summary',function()
 local old=Auctionator;Auctionator=nil
 local A,U=historyUI();local h=A.sessions
 local first=h:Begin({name='Ashenvale herbs',mapID=1440},10);h:Loot(first.id,'a',{itemID=765,itemName='Silverleaf',quantity=7});h:Stop(70)
 h:Begin({name='Redridge ore',mapID=1433},80);local second=h:Stop(100)
 U.OpenHistory(first.id);eq(U.tab,'history');assert(U.frame:IsShown());eq(U.historyView.selectedID,first.id)
 eq(U.historyView.title:GetText(),'Ashenvale herbs');eq(U.historyView.items.items[1].quantity,7);eq(U.historyView.value:IsShown(),false)
 local list=U.historyView.list;eq(list.items[1].session.id,second.id);eq(list.items[2].session.id,first.id)
 list.pool[1].scripts.OnClick(list.pool[1]);eq(U.historyView.title:GetText(),'Redridge ore')
 local other=A.SessionHistory.New(A.db,{key='Player-1-B'});A.sessions=other;U.OpenHistory();eq(#U.historyView.list.items,0);assert(U.historyView.empty:IsShown())
 Auctionator=old
end)

test('Stop opens a saved price snapshot and a restored open session can stop without a follower',function()
 local old=Auctionator;Auctionator={API={v1={GetAuctionPriceByItemID=function(_,id) if id==765 then return 250 end end}}}
 local A,U=historyUI();local h=A.sessions;local s=h:Begin({name='Herbs',mapID=1440},10)
 h:Loot(s.id,'a',{itemID=765,itemName='Silverleaf',quantity=3});h:Loot(s.id,'b',{itemID=2447,itemName='Peacebloom',quantity=2})
 U.OpenRoutes();eq(A.follower,nil);assert(U.controls.stop:IsShown());assert(A.RouteControls.frame:IsShown());eq(A.RouteControls.skip:IsEnabled(),false)
 U.actions.stop();eq(U.tab,'history');assert(U.historyView.value:GetText():find('7s 50c',1,true));assert(U.historyView.priceNote:GetText():find('1',1,true))
 Auctionator.API.v1.GetAuctionPriceByItemID=function() return 99999 end;U.OpenHistory(s.id)
 eq(U.historyView.session.valuation.totalCopper,750);eq(A.sessions:Active(),nil)
 Auctionator=old
end)

test('History keeps six tabs and virtual lists within all supported panel sizes',function()
 local A,U=historyUI();local h=A.sessions
 for i=1,90 do h:Begin({name='Session '..i},i);h:Stop(i+1) end
 U.OpenHistory()
 for _,preset in ipairs({'small','standard','large'}) do
  U.window:SetPreset(preset);U.Refresh()
  assert(U.tabs.history:IsShown());assert(U.tabs.settings.point[4]+U.tabs.settings:GetWidth()<=U.nav:GetWidth())
  assert(U.historyView.list.scroller.maximum>0);assert(#U.historyView.list.pool<25)
  assert(U.historyView.detail:GetWidth()>300);assert(U.historyView.detail.point[4]+U.historyView.detail:GetWidth()<=U.content:GetWidth())
 end
end)
