local _,A=...
local V={};A.HistoryView=V
local S=A.Skin
local function safe(s) return tostring(s or ''):gsub('|','||') end
local function show(f,on) if on then f:Show() else f:Hide() end end
local function place(f,parent,x,y,w,h)
 f:ClearAllPoints();f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);f:SetSize(math.max(1,w),math.max(1,h));return f
end
local function label(parent,text,size,color)
 return S.Label(parent,text,size or 12,color or S.text)
end
local function money(copper)
 local g=math.floor(copper/10000);local s=math.floor(copper/100)%100;local c=copper%100
 return (g>0 and g..'g ' or '')..(s>0 and s..'s ' or '')..c..'c'
end
local function stamp(value)
 if type(date)=='function' then local ok,s=pcall(date,'%d %b %Y %H:%M',value);if ok then return s end end
 return tostring(value or '')
end
local function elapsed(value)
 value=math.max(0,value or 0);return math.floor(value/3600)..'h '..math.floor(value/60)%60 ..'m '..value%60 ..'s'
end
function V.New(parent,U)
 local view={};view.frame=CreateFrame('Frame',nil,parent)
 view.heading=label(view.frame,'Route history',18,S.gold)
 view.hint=label(view.frame,'All gathering from route Start until Stop, including detours and pauses.',12,S.muted);view.hint:SetWordWrap(true)
 view.stop=S.Button(view.frame,'Stop & save session',U.actions.stop)
 view.left=S.Panel(view.frame);view.detail=S.Panel(view.frame)
 view.listHeading=label(view.left,'Recorded sessions',14,S.gold)
 view.empty=label(view.detail,'No recorded sessions yet. Start a route, then press Stop to save its summary.',13,S.muted);view.empty:SetWordWrap(true)
 view.title=label(view.detail,'',16,S.gold);view.meta=label(view.detail,'',11,S.muted);view.meta:SetWordWrap(true)
 view.stats=label(view.detail,'',12);view.stats:SetWordWrap(true)
 view.value=label(view.detail,'',13,S.gold);view.priceNote=label(view.detail,'',11,S.muted);view.priceNote:SetWordWrap(true)
 view.columns=label(view.detail,'',11,S.muted)
 view.list=A.VirtualList.New(view.left,{rowHeight=62,create=function(body)
  local row=S.Button(body,'',function() end,'quiet')
  row.label:SetJustifyH('LEFT');row.meta=label(row,'',11,S.muted)
  row:SetScript('OnClick',function() if row.item then view.selectedID=row.item.id;view.Refresh() end end)
  return row
 end,bind=function(row,item,_,width)
  row.item=item;if not item then return end
  local session=item.session
  row.label:ClearAllPoints();place(row.label,row,10,5,width-20,23)
  row.label:SetText(safe(session.routeName));place(row.meta,row,10,29,width-20,22)
  row.meta:SetText(item.live and 'In progress - press Stop to save' or stamp(session.startedAt))
  S.Selected(row,item.id==view.selectedID)
 end})
 view.items=A.VirtualList.New(view.detail,{rowHeight=32,create=function(body)
  local row=CreateFrame('Frame',nil,body)
  row.icon=row:CreateTexture(nil,'ARTWORK');row.name=label(row,'');row.quantity=label(row,'');row.quantity:SetJustifyH('RIGHT')
  row.value=label(row,'',12,S.muted);row.value:SetJustifyH('RIGHT')
  row:EnableMouse(true)
  row:SetScript('OnEnter',function()
   if row.item and GameTooltip then GameTooltip:SetOwner(row,'ANCHOR_RIGHT');pcall(GameTooltip.SetHyperlink,GameTooltip,'item:'..row.item.itemID);GameTooltip:Show() end
  end)
  row:SetScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
  return row
 end,bind=function(row,item,_,width)
  row.item=item;if not item then return end
  local priced=view.session and view.session.valuation~=nil
  place(row.icon,row,0,4,24,24);place(row.name,row,32,0,width-(priced and 192 or 106),32)
  place(row.quantity,row,width-(priced and 148 or 64),0,60,32);place(row.value,row,width-82,0,82,32)
  local icon='Interface\\Icons\\INV_Misc_QuestionMark'
  if C_Item and type(C_Item.GetItemIconByID)=='function' then local ok,value=pcall(C_Item.GetItemIconByID,item.itemID);if ok and (type(value)=='string' or A.Store.Number(value)) then icon=value end end
  row.icon:SetTexture(icon);row.name:SetText(safe(item.name or ('Item '..item.itemID)));row.quantity:SetText(tostring(item.quantity))
  show(row.value,priced);row.value:SetText(item.totalCopper and money(item.totalCopper) or 'Unpriced')
 end})
 function view.Layout(width,height)
  view.width=width;view.height=height;place(view.frame,parent,0,0,width,height)
  place(view.heading,view.frame,14,8,width-210,28);place(view.hint,view.frame,14,36,width-210,34)
  place(view.stop,view.frame,width-186,16,172,26)
  local left=math.min(290,math.max(220,width*.30));local right=width-left-26
  place(view.left,view.frame,8,82,left,height-90);place(view.detail,view.frame,left+18,82,right,height-90)
  place(view.listHeading,view.left,12,8,left-24,24);place(view.list.frame,view.left,8,36,left-16,height-134)
  view.list:Layout(left-16,height-134)
  place(view.empty,view.detail,16,16,right-32,90)
  place(view.title,view.detail,14,10,right-28,28);place(view.meta,view.detail,14,40,right-28,34)
  place(view.stats,view.detail,14,78,right-28,36);place(view.value,view.detail,14,118,right-28,24)
  place(view.priceNote,view.detail,14,143,right-28,34)
  local top=view.session and view.session.valuation and 184 or 120
  place(view.columns,view.detail,14,top,right-28,22)
  place(view.items.frame,view.detail,14,top+26,right-28,height-90-top-38)
  view.items:Layout(right-28,height-90-top-38)
 end
 function view.Refresh()
  local h=A.sessions
  if view.owner and view.owner~=h then view.selectedID=nil end;view.owner=h
  local active=h and h:Active();local records={}
  if active then records[#records+1]={id='active',session=active,live=true} end
  for _,session in ipairs(h and h:List() or {}) do records[#records+1]={id=session.id,session=session} end
  local selected
  for _,record in ipairs(records) do if record.id==view.selectedID then selected=record end end
  selected=selected or records[1];view.selectedID=selected and selected.id;view.session=selected and selected.session
  show(view.stop,active~=nil);show(view.empty,not selected)
  if not selected then
   view.title:SetText('');view.meta:SetText('');view.stats:SetText('');view.columns:SetText('');view.value:Hide();view.priceNote:Hide();view.items:SetItems({})
  else
   local session=selected.session;local quantities,rows=0,{}
   for _,item in pairs(session.items) do quantities=quantities+item.quantity;rows[#rows+1]=item end
   table.sort(rows,function(a,b) local an,bn=a.name or '',b.name or '';if an==bn then return a.itemID<b.itemID end;return an<bn end)
   view.title:SetText(safe(session.routeName))
   local zone=session.mapID and U.ZoneName(session.mapID) or 'Route session'
   view.meta:SetText(safe(stamp(session.startedAt)..'  /  '..zone..'\n'..(session.characterName or 'This character')..(session.realm and (' - '..session.realm) or '')))
   local duration=selected.live and math.max(0,A.Client.Timestamp()-session.startedAt) or session.duration
   view.stats:SetText(session.gathers..' successful gathers ('..session.herbGathers..' herb, '..session.oreGathers..' ore)\n'..quantities..' items  /  '..elapsed(duration))
   local valuation=session.valuation;show(view.value,valuation~=nil);show(view.priceNote,valuation~=nil)
   if valuation then
    view.value:SetText('Estimated auction value: '..money(valuation.totalCopper))
    view.priceNote:SetText(valuation.unpricedKinds>0 and ('Partial value: '..valuation.unpricedKinds..' item types unpriced. Auctionator prices at Stop, before fees.') or 'Auctionator prices saved at Stop, before auction fees.')
   end
   view.columns:SetText(valuation and 'Resource / quantity / auction value' or 'Resource / quantity')
   view.items:SetItems(rows,view.itemSession~=session.id);view.itemSession=session.id
  end
  view.list:SetItems(records)
  if view.width then view.Layout(view.width,view.height) end
 end
 return view
end
