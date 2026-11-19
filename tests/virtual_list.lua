local function setup()
 dofile('tests/wow.lua');fakeUI();local A={};for _,m in ipairs({'Store','Skin','ScrollPanel','VirtualList'}) do module(m,A) end;return A
end
test('virtual lists reach all items using a viewport-sized recycled pool',function()
 local A=setup();local list=A.VirtualList.New(UIParent,{rowHeight=24,create=function(p) return CreateFrame('Button',nil,p) end,bind=function(row,item) row.item=item end})
 local items={};for i=1,5000 do items[i]={id=tostring(i)} end
 list:Layout(400,240,1);list:SetItems(items,true);assert(#list.pool<=12);eq(list.pool[1].item.id,'1')
 list:SetOffset(1000000);local last=false;for _,row in ipairs(list.pool) do if row:IsShown() and row.item.id=='5000' then last=true end end;assert(last)
 list:SetItems({},true);for _,row in ipairs(list.pool) do eq(row:IsShown(),false) end
end)
test('virtual grid reflow preserves first visible resource and query reset clears scroll',function()
 local A=setup();local list=A.VirtualList.New(UIParent,{rowHeight=90,create=function(p) return CreateFrame('Button',nil,p) end,bind=function(row,item) row.item=item end})
 local items={};for i=1,100 do items[i]={id=tostring(i)} end
 list:Layout(800,270,8);list:SetItems(items,true);list:SetOffset(270);local first=list:Anchor().id
 list:Layout(600,270,6);local found=false;for _,r in ipairs(list.pool) do if r:IsShown() and r.item.id==first then found=true end end;assert(found)
 list:SetItems(items,true);eq(list.scroller.offset,0)
end)
