local _,A=...
A.GroupPicker={}
function A.GroupPicker.New(parent,onSelect)
 local S=A.Skin;local v={rows={},offset=0};local f=S.Panel(parent);v.frame=f;f:SetSize(316,250);f:SetFrameStrata('TOOLTIP');f:SetFrameLevel(parent:GetFrameLevel()+40);f:SetClampedToScreen(true);f:Hide()
 local title=S.Label(f,'Choose a known location',13,S.gold);title:SetPoint('TOPLEFT',f,'TOPLEFT',12,-10);title:SetSize(264,20)
 local close=S.Button(f,'x',function() f:Hide() end,'quiet');close:SetPoint('TOPRIGHT',f,'TOPRIGHT',-5,-5);close:SetSize(24,24)
 local function refresh()
  local nodes=v.members or {};f:SetHeight(42+math.min(8,#nodes)*25);local max=math.max(0,#nodes-8);v.offset=math.max(0,math.min(max,v.offset))
  for i,row in ipairs(v.rows) do
   local n=nodes[v.offset+i];row.node=n;row.nodeKey=n and A.FarmingSession.Key(n)
   if n then
    row:SetText((n.name or 'Known resource'):gsub('|','||')..' / '..(n.confirmed and 'personal' or 'imported'));row.icon:SetTexture(A.Resources.Icon(n));row:Show()
   else row:Hide() end
  end
  v.syncing=true;v.bar:SetMinMaxValues(0,max);v.bar:SetValue(v.offset);v.bar:SetEnabled(max>0);v.bar:SetHeight(math.max(24,math.min(8,#nodes)*25-4));if max>0 then v.bar:Show() else v.bar:Hide() end;v.syncing=false
 end
 local function wheel(_,delta) v.offset=v.offset-delta;refresh() end
 for i=1,8 do
  local b=S.Button(f,'',function(self) local key=self.nodeKey;f:Hide();if key then onSelect(key) end end,'quiet');b:SetPoint('TOPLEFT',f,'TOPLEFT',9,-(35+(i-1)*25));b:SetSize(274,24)
  b.label:ClearAllPoints();b.label:SetPoint('LEFT',b,'LEFT',26,0);b.label:SetSize(246,24);b.label:SetJustifyH('LEFT')
  b.icon=b:CreateTexture(nil,'ARTWORK');b.icon:SetPoint('LEFT',b,'LEFT',3,0);b.icon:SetSize(18,18)
  b:EnableMouseWheel(true);b:SetScript('OnMouseWheel',wheel)
  A.SkillTooltip.Bind(b,'Known location',function() return b.node and {{node=b.node}} or {} end)
  v.rows[i]=b
 end
 v.bar=S.Slider(f,0,0,1,function(_,value) if not v.syncing then v.offset=math.floor(value+.5);refresh() end end)
 v.bar:SetOrientation('VERTICAL');v.bar:SetPoint('TOPRIGHT',f,'TOPRIGHT',-9,-37);v.bar:SetSize(14,196);v.bar.lowLabel:Hide();v.bar.highLabel:Hide()
 f:EnableMouseWheel(true);f:SetScript('OnMouseWheel',wheel)
 function v:Open(members,anchor,plan,viewKey)
  self.members=members;self.offset=0;self.plan=plan;self.viewKey=viewKey;self.revision=plan and plan.revision
  f:ClearAllPoints();f:SetPoint('TOPLEFT',anchor,'BOTTOMLEFT',0,-4);refresh();f:Show()
 end
 function v:Close() f:Hide();self.members=nil end
 return v
end
