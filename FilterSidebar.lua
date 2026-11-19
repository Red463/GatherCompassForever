local _, A = ...
local V={};A.FilterSidebar=V
local S=A.Skin
local function place(f,parent,x,y,w,h) f:SetPoint('TOPLEFT',parent,'TOPLEFT',x,-y);f:SetSize(w,h);return f end
local function label(parent,text,x,y,w,h,size,color) return place(S.Label(parent,text,size or 12,color or S.text),parent,x,y,w,h) end
function V.New(parent,U)
 local view={rows={},offset=0,maximum=0}
 local f=place(S.Panel(parent),parent,0,0,194,414);view.frame=f
 local function check(key,text,x,y,width,click)
  local b=place(S.Check(f,text,click),f,x,y,24,24);b.label:SetWidth(width);b:SetHitRectInsets(0,-width-4,0,0);U.controls[key]=b;return b
 end
 label(f,'Node source',14,10,164,20,13,S.gold)
 check('sourceConfirmed','My discoveries',12,34,136,function() U.ToggleSource('confirmed') end)
 check('sourceImported','Imported locations',12,60,144,function() U.ToggleSource('imported') end)
 view.count=label(f,'',16,88,164,18,11,S.muted)
 label(f,'Gathering',14,113,164,20,13,S.gold)
 check('kindHerb','Herbs',12,138,52,function() U.ToggleKind('herb') end)
 check('kindOre','Ore',104,138,42,function() U.ToggleKind('ore') end)
 view.title=label(f,'Materials',14,170,164,22,13,S.gold)
 check('allMaterials','All',12,197,30,function() local state=A.Selection.BulkState(A.db,A.Resources.Skills());U.BulkMaterials('all',not state.all) end)
 check('gatherableMaterials','Gatherable',76,197,80,function() local skills,context=A.Resources.Skills();local state=A.Selection.BulkState(A.db,skills,context);U.BulkMaterials('gatherable',not state.gatherable) end)
 check('skillMaterials','Skill-ups',12,223,136,function() local skills,context=A.Resources.Skills();local state=A.Selection.BulkState(A.db,skills,context);U.BulkMaterials('skillups',not state.skillups) end)
 S.Hint(U.controls.allMaterials,'All materials','Tick to select every material, including newly discovered resources. Untick to clear the selection.')
 S.Hint(U.controls.skillMaterials,'Select skill-up materials','Select known orange, yellow and green materials across all zones matching the chosen source and gathering type. This selects once; individual materials remain editable.')
 S.Hint(U.controls.gatherableMaterials,'All gatherable materials','Select resources you can gather, including grey resources that no longer grant skill-ups. Unknown requirements and too-difficult resources stay unselected. Individual choices remain editable.')
 local scroll=place(CreateFrame('ScrollFrame',nil,f),f,12,258,150,142);view.scroll=scroll
 local child=CreateFrame('Frame',nil,scroll);child:SetSize(150,142);scroll:SetScrollChild(child);view.child=child
 local bar=place(S.Slider(f,0,0,1,function(_,value) if not view.syncing then view:SetOffset(value) end end),f,168,258,14,142)
 bar:SetOrientation('VERTICAL');bar:SetThumbTexture('Interface\\Buttons\\UI-ScrollBar-Knob');bar.lowLabel:Hide();bar.highLabel:Hide();view.scrollbar=bar
 local thumb=bar:GetThumbTexture();if type(thumb)=='table' or type(thumb)=='userdata' then thumb:SetSize(18,24) end
 function view:SetOffset(value)
  if not A.Store.Number(value) then return end
  self.offset=math.max(0,math.min(self.maximum,value));self.scroll:SetVerticalScroll(self.offset)
  self.syncing=true;self.scrollbar:SetValue(self.offset);self.syncing=false
 end
 local function wheel(_,delta) if A.Store.Number(delta) then view:SetOffset(view.offset-delta*24) end end
 scroll:EnableMouseWheel(true);scroll:SetScript('OnMouseWheel',wheel);bar:EnableMouseWheel(true);bar:SetScript('OnMouseWheel',wheel)
 view.empty=label(f,'',16,266,140,128,12,S.muted);view.empty:SetWordWrap(true)
 local function row(index)
  local b=place(S.Button(child,'',function(self) if self.materialID then U.ToggleMaterial(self.materialID) end end,'quiet'),child,0,(index-1)*24,150,24)
  b.box=b:CreateTexture(nil,'ARTWORK');b.box:SetTexture('Interface\\Buttons\\UI-CheckBox-Up');b.box:SetSize(20,20);b.box:SetPoint('LEFT',b,'LEFT',0,0)
  b.check=b:CreateTexture(nil,'OVERLAY');b.check:SetTexture('Interface\\Buttons\\UI-CheckBox-Check');b.check:SetSize(20,20);b.check:SetPoint('LEFT',b,'LEFT',0,0)
  b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetSize(18,18);b.icon:SetPoint('LEFT',b,'LEFT',24,0)
  b.label:ClearAllPoints();b.label:SetPoint('LEFT',b,'LEFT',46,0);b.label:SetSize(104,22);b.label:SetJustifyH('LEFT')
  b:EnableMouseWheel(true);b:SetScript('OnMouseWheel',wheel)
  A.SkillTooltip.Bind(b,'Material selection',function() return b.materialDetails and {{node=b.materialNode,details=b.materialDetails}} or {} end)
  view.rows[index]=b;return b
 end
 function view.Refresh(player)
  local filter=U.Filter();local scope=U.tab=='atlas' and U.atlasView and U.atlasView.scope or 'current'
  local mapID=scope=='current' and player and player.mapID or A.Store.Number(scope) and scope or nil
  local unresolved=scope=='current' and not mapID
  local entries=unresolved and {} or A.Selection.Materials(A.db,mapID,filter);local skills,context=A.Resources.Skills();local selected=0
  for i,entry in ipairs(entries) do
   local b=view.rows[i] or row(i);b.materialID=entry.id;b.materialName=entry.name;b.materialNode=entry.sample
   b.materialDetails=A.Resources.SkillDetails(entry.sample,skills,context);b.labelColor=b.materialDetails.color
   local on=not filter.materials or filter.materials[entry.id]
   if on then selected=selected+1;b.check:Show() else b.check:Hide() end
   b:SetText(entry.name:gsub('|','||'));b.icon:SetTexture(A.Resources.Icon(entry.sample));S.Selected(b,on);b:Show()
  end
  for i=#entries+1,#view.rows do view.rows[i].materialID=nil;view.rows[i]:Hide() end
  child:SetHeight(math.max(scroll:GetHeight(),#entries*24));scroll:UpdateScrollChildRect()
  view.maximum=math.max(0,#entries*24-scroll:GetHeight());view.syncing=true;bar:SetMinMaxValues(0,view.maximum);bar:SetEnabled(view.maximum>0);view.syncing=false;view:SetOffset(view.offset)
  view.empty:SetText(unresolved and 'Position unavailable. Return to a gathering zone.' or filter.source=='none' and 'Tick a node source above.' or filter.kind=='none' and 'Tick Herbs or Ore above.' or 'No matching materials here. Import data on Welcome or gather in this zone.')
  if #entries==0 then view.empty:Show() else view.empty:Hide() end
  U.controls.sourceConfirmed:SetChecked(filter.source=='combined' or filter.source=='confirmed');U.controls.sourceImported:SetChecked(filter.source=='combined' or filter.source=='imported')
  U.controls.kindHerb:SetChecked(filter.kind=='both' or filter.kind=='herb');U.controls.kindOre:SetChecked(filter.kind=='both' or filter.kind=='ore')
  local state=A.Selection.BulkState(A.db,skills,context);U.controls.allMaterials:SetChecked(state.all);U.controls.skillMaterials:SetChecked(state.skillups);U.controls.skillMaterials:SetEnabled(state.eligible>0)
  U.controls.gatherableMaterials:SetChecked(state.gatherable);U.controls.gatherableMaterials:SetEnabled(state.gatherableCount>0)
  view.title:SetText('Materials  '..selected..'/'..#entries)
  local matching=0
  if scope=='all' then for id in pairs(A.db.nodes) do matching=matching+#A.Store.Select(A.db,id,filter) end else matching=#A.Store.Select(A.db,mapID,filter) end
  view.count:SetText(matching..' matching locations')
  U.zone:SetText((scope=='all' and 'All zones' or U.ZoneName(mapID))..'  -  '..matching..' matching locations')
 end
 return view
end
