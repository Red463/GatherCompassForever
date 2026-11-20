local function historySetup(db,key)
 local A={};module('Store',A);module('SessionHistory',A)
 db=db or A.Store.Open();return A,A.SessionHistory.New(db,{key=key or 'Player-1-A',name=key or 'Tom',realm='Test'}),db
end

test('route journals stay open until Stop and isolate character history across reloads',function()
 local A,h,db=historySetup();local route={name='Ashenvale herbs',mapID=1440}
 local first=h:Begin(route,100);eq(h:Begin({name='Replacement',mapID=1433},110),first)
 eq(#h:List(),0);eq(first.startedAt,100)
 local _,other=historySetup(db,'Player-1-B');eq(other:Active(),nil);eq(#other:List(),0)
 local _,reloaded=historySetup(A.Store.Copy(db));eq(reloaded:Active().id,first.id)
 local saved=reloaded:Stop(160);eq(saved.duration,60);eq(saved.routeName,'Ashenvale herbs');eq(#reloaded:List(),1);eq(reloaded:Active(),nil)
 eq(reloaded:Stop(170),nil);eq(#other:List(),0)
end)

test('session journals count detour actions and actual item quantities without duplicate receipts',function()
 local A,h=historySetup();local session=h:Begin({name='Herbs',mapID=1440},100)
 local o={sessionID=session.id,castGUID='cast1',kind='ore',mapID=1433,name='Copper Vein'}
 assert(h:Gather(o));eq(h:Gather(o),nil);eq(session.gathers,1);eq(session.oreGathers,1)
 assert(h:Loot(session.id,'receipt1',{itemID=2770,itemName='Copper Ore',quantity=3}))
 eq(h:Loot(session.id,'receipt1',{itemID=2770,quantity=3}),nil)
 assert(h:Loot(session.id,'receipt2',{itemID=2770,quantity=2}));eq(session.items[2770].quantity,5)
 eq(h:Loot('wrong','r3',{itemID=2770,quantity=99}),nil)
 for _,n in ipairs({0,-1,.5,0/0,math.huge}) do eq(h:Loot(session.id,'bad'..tostring(n),{itemID=2770,quantity=n}),nil) end
 local oldID=session.id;h:Stop(200);local nextSession=h:Begin({name='Next'},210)
 assert(nextSession.id~=oldID);eq(h:Loot(oldID,'late',{itemID=2770,quantity=5}),nil);eq(nextSession.gathers,0)
end)

test('Auctionator prices are optional snapshots with explicit missing price coverage',function()
 local previous=Auctionator;Auctionator=nil
 local A,h=historySetup();local s=h:Begin({},10);h:Loot(s.id,'a',{itemID=765,quantity=3})
 eq(h:Stop(20).valuation,nil)
 local s2=h:Begin({},30);h:Loot(s2.id,'b',{itemID=765,quantity=3});h:Loot(s2.id,'c',{itemID=2447,quantity=2})
 Auctionator={API={v1={GetAuctionPriceByItemID=function(caller,id) eq(caller,'Gatherly');if id==765 then return 250 end end}}}
 local saved=h:Stop(40);eq(saved.valuation.totalCopper,750);eq(saved.valuation.unpricedKinds,1);eq(saved.items[765].unitPrice,250);eq(saved.items[2447].unitPrice,nil)
 Auctionator.API.v1.GetAuctionPriceByItemID=function() error('Unavailable') end
 local s3=h:Begin({},50);h:Loot(s3.id,'d',{itemID=765,quantity=2});eq(h:Stop(60).valuation.unpricedKinds,1)
 eq(saved.valuation.totalCopper,750);eq(#h:List(),3);eq(h:List()[1].id,s3.id)
 Auctionator=previous
end)

test('missing character identity and unknown history schemas never share or overwrite history',function()
 local A,h,db=historySetup();eq(A.SessionHistory.New(db,nil),nil)
 local future={version=99,characters={keep=true}};db.sessionHistory=future
 eq(A.SessionHistory.New(db,{key='a'}),nil);eq(db.sessionHistory,future);eq(future.characters.keep,true)
end)

test('malformed optional Auctionator API cannot prevent saving a stopped session',function()
 local previous=Auctionator
 for _,addon in ipairs({true,{API=true},{API={v1=true}},{API={v1='unavailable'}}}) do
  local A,h=historySetup();local s=h:Begin({},10);h:Loot(s.id,'a',{itemID=765,quantity=3})
  Auctionator=addon;local ok,saved=pcall(h.Stop,h,20);Auctionator=previous
  assert(ok,saved);assert(saved);eq(saved.valuation,nil);eq(h:Active(),nil);eq(#h:List(),1)
 end
 Auctionator=previous
end)
