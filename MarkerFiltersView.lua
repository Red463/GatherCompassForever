local _,A=...
local V={};A.MarkerFiltersView=V
function V.New(parent,U)
 local S=A.Skin;local view={};view.frame=CreateFrame('Frame',nil,parent);local f=view.frame
 local function place(o,x,y,w,h) o:SetPoint('TOPLEFT',f,'TOPLEFT',x,-y);o:SetSize(w,h);return o end
 local function label(text,x,y,w,h,color) return place(S.Label(f,text,12,color or S.text),x,y,w,h) end
 local function settings() return A.Selection.MarkerSettings(A.db.settings) end
 local function changed()
  U.Refresh();if A.Map then A.Map.SetNodeFocus(nil);A.Map.Refresh(A.db,U.DisplayRoute(),A.follower) end
 end
 local function check(key,text,x,y,width,click)
  local b=place(S.Check(f,text,click),x,y,24,24);b.label:SetWidth(width);b:SetHitRectInsets(0,-width-4,0,0);U.controls[key]=b;return b
 end
 label('Map-marker sources',0,0,234,20,S.gold)
 check('markerConfirmed','My discoveries',0,26,180,function() A.Selection.ToggleSource(settings(),'confirmed');changed() end)
 check('markerImported','Imported locations',0,52,180,function() A.Selection.ToggleSource(settings(),'imported');changed() end)
 label('Gathering',0,88,234,20,S.gold)
 check('markerHerb','Herbs',0,114,60,function() A.Selection.ToggleKind(settings(),'herb');changed() end)
 check('markerOre','Ore',110,114,60,function() A.Selection.ToggleKind(settings(),'ore');changed() end)
 check('markerRouteOverride','Use route selections while following',0,158,210,function() A.db.settings.routeMarkerOverride=not A.db.settings.routeMarkerOverride;changed() end)
 U.controls.markerRouteOverride.label:SetWordWrap(true);U.controls.markerRouteOverride.label:SetSize(210,40)
 view.notice=label('',0,204,238,60,S.muted);view.notice:SetWordWrap(true)
 view.heading=label('Materials shown on both maps',260,0,500,20,S.gold)
 local function bulk(mode)
  local ranks,ctx=A.Resources.Skills();local state=A.Selection.BulkState(A.db,ranks,ctx,settings())
  A.Selection.Bulk(A.db,mode,not state[mode],ranks,ctx,settings());changed()
 end
 check('markerAll','All',260,26,40,function() bulk('all') end)
 check('markerGatherable','Gatherable',350,26,100,function() bulk('gatherable') end)
 check('markerSkillups','Skill-ups',494,26,100,function() bulk('skillups') end)
 view.list=A.VirtualList.New(f,{rowHeight=26,create=function(p)
  local b=S.Button(p,'',function(self) if self.entry then A.Selection.ToggleMaterial(A.db,self.entry.id,settings());changed() end end,'quiet')
  b.box=b:CreateTexture(nil,'ARTWORK');b.box:SetTexture('Interface\\Buttons\\UI-CheckBox-Up');b.box:SetSize(20,20);b.box:SetPoint('LEFT',b,'LEFT',0,0)
  b.tick=b:CreateTexture(nil,'OVERLAY');b.tick:SetTexture('Interface\\Buttons\\UI-CheckBox-Check');b.tick:SetSize(20,20);b.tick:SetPoint('LEFT',b,'LEFT',0,0)
  b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(20,20);b.icon:SetPoint('LEFT',b,'LEFT',26,0)
  b.label:ClearAllPoints();b.label:SetPoint('LEFT',b,'LEFT',54,0);b.label:SetJustifyH('LEFT')
  A.SkillTooltip.Bind(b,'Map marker',function() return b.entry and {{node=b.entry.sample}} or {} end)
  return b
 end,bind=function(b,entry,_,width)
  b.entry=entry;if not entry then return end
  local filter=A.Selection.Filter(settings());local on=not filter.materials or filter.materials[entry.id]
  if on then b.tick:Show() else b.tick:Hide() end
  b.icon:SetTexture(A.Resources.Icon(entry.sample));local ranks,ctx=view.skills,view.context;b.labelColor=A.Resources.SkillDetails(entry.sample,ranks,ctx).color
  b.label:SetSize(width-60,24);b:SetText(entry.name:gsub('|','||'));S.Selected(b,on)
 end})
 view.empty=label('No known resources match. Add data on Welcome or change the sources above.',260,76,440,60,S.muted);view.empty:SetWordWrap(true)
 function view.Layout(w,h)
  f:SetSize(w,h);view.heading:SetWidth(w-260);view.empty:SetWidth(w-280)
  view.list.frame:ClearAllPoints();view.list.frame:SetPoint('TOPLEFT',f,'TOPLEFT',260,-60);view.list:Layout(w-260,math.max(80,h-60),1)
 end
 function view.Refresh()
  local filter=A.Selection.Filter(settings());local ranks,ctx=A.Resources.Skills();view.skills=ranks;view.context=ctx;local state=A.Selection.BulkState(A.db,ranks,ctx,settings())
  for key,value in pairs({markerConfirmed=filter.source=='combined' or filter.source=='confirmed',markerImported=filter.source=='combined' or filter.source=='imported',markerHerb=filter.kind=='both' or filter.kind=='herb',markerOre=filter.kind=='both' or filter.kind=='ore',markerAll=state.all,markerGatherable=state.gatherable,markerSkillups=state.skillups,markerRouteOverride=A.db.settings.routeMarkerOverride}) do U.controls[key]:SetChecked(value) end
  local entries=A.Selection.Materials(A.db,nil,settings());view.list:SetItems(entries,false)
  if #entries==0 then view.empty:Show() else view.empty:Hide() end
  local _,override=U.MarkerFilter();view.notice:SetText(override and 'Active route selections currently control markers. Stop the route to restore these everyday choices.' or 'Everyday choices control map and minimap markers in every zone. Choose route targets separately in Routes.')
 end
 return view
end
