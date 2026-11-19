local function heat()
 dofile('tests/wow.lua');fakeUI();local A={};for _,n in ipairs({'Store','Heatmap','MiniHeat'}) do module(n,A) end;return A
end

test('moving heat refresh reuses its scratch arrays and strip records after warmup',function()
 local A=heat();local route={width=1000,height=500,corridor=true,heatRadius=117,coverageRadius=180,points={{x=.1,y=.5},{x=.9,y=.5}}}
 local work={};local offset=0
 local function project(p) return (p.x-.5)*500+offset,0 end
 local function radius(r) return r*.5,r*.5 end
 local function run() return A.MiniHeat.Field(route,project,200,200,'SQUARE',{},.65,radius,work) end
 local first=run();local strip=first[1];run();eq(first[1],strip)
 collectgarbage('collect');collectgarbage('stop');local before=collectgarbage('count')
 for i=1,40 do offset=(i%2)*.01;run() end
 local allocated=collectgarbage('count')-before;collectgarbage('restart')
 assert(allocated<64,'Warm heat refresh allocated '..allocated..' KiB of garbage')
 local actual=A.Store.Copy(run());local expected=A.MiniHeat.Field(route,project,200,200,'SQUARE',{},.65,radius)
 eq(#actual,#expected);for i,c in ipairs(actual) do near(c.alpha,expected[i].alpha);near(c.x,expected[i].x);near(c.alphaRight,expected[i].alphaRight) end
end)

test('modern gradient colours are reused when alpha changes during movement',function()
 local saved=CreateColor;local ok,err=pcall(function()
  local A=heat();local count,updates=0,0
  CreateColor=function(r,g,b,a)
   count=count+1;return {r=r,g=g,b=b,a=a,SetRGBA=function(self,nr,ng,nb,na) updates=updates+1;self.r,self.g,self.b,self.a=nr,ng,nb,na end}
  end
  local create=Minimap.CreateTexture;Minimap.CreateTexture=function(self,...) local t=create(self,...);t.SetGradientAlpha=false;return t end
  local field={{x=0,y=20,width=8,height=2,alpha=.4,alphaLeft=.2,alphaRight=.6,green=.6}};local pool={}
  A.MiniHeat.Draw(pool,Minimap,field,'SQUARE');eq(count,2)
  field[1].alphaLeft=.3;field[1].alphaRight=.5;A.MiniHeat.Draw(pool,Minimap,field,'SQUARE');eq(count,2)
  near(pool[1].gradient.left[4],.3);near(pool[1].gradient.right[4],.5)
  assert(updates>=2,'Native colour setters must update both cached endpoints')
 end);CreateColor=saved;assert(ok,err)
end)

test('reusable heat scratch clears resized grids and changed holes shapes and opacity',function()
 local A=heat();local route={width=1000,height=500,corridor=true,heatRadius=117,coverageRadius=180,points={{x=.2,y=.5},{x=.8,y=.5}}}
 local work={};local function project(p) return (p.x-.5)*500,0 end
 local function radius(r) return r*.5,r*.5 end
 for i=1,24 do
  local w,h=i%2==0 and 223 or 128,i%3==0 and 217 or 86
  local shape=({'ROUND','SQUARE','CORNER-TOPLEFT','UNKNOWN'})[i%4+1]
  local holes=i%2==0 and {{x=20,y=0,r=8,feather=4}} or {}
  local opacity=i%5==0 and 0 or .65
  local actual=A.MiniHeat.Field(route,project,w,h,shape,holes,opacity,radius,work)
  local expected=A.MiniHeat.Field(route,project,w,h,shape,holes,opacity,radius)
  eq(#actual,#expected)
  for n,c in ipairs(actual) do for _,key in ipairs({'x','y','width','height','alpha','green','alphaLeft','alphaRight','greenLeft','greenRight'}) do near(c[key],expected[n][key]) end end
 end
end)

local function map()
 dofile('tests/wow.lua');fakeUI();local A={};for _,n in ipairs({'Store','Client','Map'}) do module(n,A) end
 A.db=A.Store.Open();A.db.nodes[1]={};for i=1,1000 do A.db.nodes[1][i]={key='n'..i,mapID=1,x=.02+(i%40)*.024,y=.02+math.floor(i/40)*.038,kind='herb',materialID='gm:herb:401',name='Peacebloom',imported=true} end
 A.Client.Position=function() return {mapID=1,x=.5,y=.5} end;A.Client.Size=function() return 6000,4000 end
 local calls=0;A.Client.Distance=function(a,b) calls=calls+1;return math.sqrt(((a.x-b.x)*6000)^2+((a.y-b.y)*4000)^2) end
 C_Minimap={GetViewRadius=function() return 200 end};GetCVar=function() return '0' end
 LibStub=function() return {AddWorldMapIconMap=function() end,AddMinimapIconMap=function() end,RemoveWorldMapIcon=function() end,RemoveMinimapIcon=function() end} end
 return A,function() return calls end
end

test('closed world map does not rebuild or style its hidden marker list',function()
 local A=map();local world=0;local style=A.Resources.Presentation
 A.Resources.Presentation=function(node,settings,mini,...) if not mini then world=world+1 end;return style(node,settings,mini,...) end
 WorldMapFrame:Hide();A.Map.Refresh(A.db,nil);eq(world,0)
 WorldMapFrame:Show();assert(world>0,'Opening the map must restore world markers immediately')
 LibStub=nil;C_Minimap=nil;GetCVar=nil
end)

test('minimap only measures and sorts nearby markers instead of the whole zone',function()
 local A,calls=map();WorldMapFrame:Hide();A.Resources.Settings(A.db.settings).groupMini=false;A.Map.Refresh(A.db,nil)
 assert(calls()<60,'Measured '..calls()..' nodes for a small minimap')
 eq(A.Map.byKey['m:node:n1'],nil);local count=0;for _,pin in ipairs(A.Map.pins) do if pin.key and pin.mini then count=count+1 end end
 assert(count>0 and count<60);LibStub=nil;C_Minimap=nil;GetCVar=nil
end)

test('map selection cache reuses stable queries and invalidates filters and gathered node revisions',function()
 local A=map();WorldMapFrame:Hide();local calls=0;local select=A.Store.Select
 A.Store.Select=function(...) calls=calls+1;return select(...) end
 A.Map.Refresh(A.db,nil);local first=calls;A.Map.Refresh(A.db,nil);eq(calls,first)
 local filter=A.Selection.MarkerSettings(A.db.settings);filter.kind='ore';A.Map.Refresh(A.db,nil);assert(calls>first);local changed=calls
 filter.kind='herb';A.Map.Refresh(A.db,nil);A.db.nextNode=2000
 local n=A.Store.Observe(A.db,{mapID=1,x=.5,y=.5,kind='herb',materialID='gm:herb:401',source='confirmed',name='Peacebloom'})
 assert(n);local before=calls;A.Map.Refresh(A.db,nil);assert(calls>before);assert(A.Map.byKey['m:node:'..n.key] or A.Map.miniGroups)
 filter.materials={};before=calls;A.Map.Refresh(A.db,nil);assert(calls>before)
 for _,pin in ipairs(A.Map.pins) do if pin.key and pin.node then error('Deselected cached marker survived') end end
 assert(changed>first);LibStub=nil;C_Minimap=nil;GetCVar=nil
end)

test('unrecognised minimap shapes retain the pin library fallback instead of losing markers',function()
 local A=map();WorldMapFrame:Hide();GetMinimapShape=function() return 'CUSTOM' end;A.Map.Refresh(A.db,nil)
 local visible=false;for _,pin in ipairs(A.Map.pins) do if pin.key and pin.mini then visible=true end end;assert(visible)
 LibStub=nil;C_Minimap=nil;GetCVar=nil;GetMinimapShape=nil
end)
