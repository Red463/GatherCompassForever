local _,A=...
local V={};A.VirtualList=V
function V.New(parent,options)
 local self={items={},pool={},columns=1,width=1,height=1,rowHeight=options.rowHeight or 24}
 local scroll=A.ScrollPanel.New(parent);self.scroller=scroll;self.frame=scroll.frame;self.body=scroll.body
 local function id(item) return item and (item.id or item.mapID or item.materialID or item) end
 function self:Anchor()
  local row=math.floor(scroll.offset/self.rowHeight);local item=self.items[row*self.columns+1]
  return {id=id(item),fraction=scroll.offset-row*self.rowHeight}
 end
 function self:Restore(anchor)
  if not anchor or not anchor.id then return end
  for i,item in ipairs(self.items) do if id(item)==anchor.id then self:SetOffset(math.floor((i-1)/self.columns)*self.rowHeight+(anchor.fraction or 0));return end end
 end
 function self:Render()
  if self.layouting then return end
  local start=math.floor(scroll.offset/self.rowHeight);local count=(math.ceil(self.height/self.rowHeight)+1)*self.columns
  local cw=self.body:GetWidth()/self.columns
  for slot=1,count do
   local index=(start+math.floor((slot-1)/self.columns))*self.columns+(slot-1)%self.columns+1;local item=self.items[index]
   local row=self.pool[slot]
   if item and not row then
    row=options.create(self.body);self.pool[slot]=row;row:EnableMouseWheel(true)
    row:SetScript('OnMouseWheel',function(_,delta) self:SetOffset(scroll.offset-delta*self.rowHeight) end)
   end
   if row then
    if row.boundID~=id(item) and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(row) then GameTooltip:Hide() end
    row.boundID=id(item);options.bind(row,item,index,cw)
    if item then row:ClearAllPoints();row:SetPoint('TOPLEFT',self.body,'TOPLEFT',((slot-1)%self.columns)*cw,-(start+math.floor((slot-1)/self.columns))*self.rowHeight);row:SetSize(cw,self.rowHeight);row:Show() else row:Hide() end
   end
  end
  for i=count+1,#self.pool do options.bind(self.pool[i],nil);self.pool[i]:Hide() end
 end
 local offset=scroll.SetOffset
 function scroll:SetOffset(value) offset(self,value);self.owner:Render() end;scroll.owner=self
 function self:SetOffset(value) scroll:SetOffset(value) end
 function self:Layout(w,h,columns)
  local anchor=self:Anchor();self.layouting=true;self.width=w;self.height=h;self.columns=math.max(1,columns or self.columns)
  scroll:Layout(w,h,math.ceil(#self.items/self.columns)*self.rowHeight);self.layouting=nil;self:Restore(anchor);self:Render()
 end
 function self:SetItems(items,reset)
  local anchor=not reset and self:Anchor();self.items=items or {};self.layouting=true
  scroll:Layout(self.width,self.height,math.ceil(#self.items/self.columns)*self.rowHeight)
  if reset then scroll:SetOffset(0) end;self.layouting=nil;self:Restore(anchor);self:Render()
 end
 return self
end
