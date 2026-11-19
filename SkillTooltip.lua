local _,A=...
local T={};A.SkillTooltip=T
local function safe(v) return tostring(v or ''):gsub('|','||') end
function T.Show(owner,title,entries,extra)
 if not GameTooltip then return end
 GameTooltip:SetOwner(owner,'ANCHOR_RIGHT');GameTooltip:SetText(safe(title or 'Known resource'),1,.82,.35)
 local skills,context=A.Resources.Skills()
 for i,e in ipairs(entries or {}) do
  if i>8 then GameTooltip:AddLine('More resources in this group: '..(#entries-8),.7,.7,.7);break end
  local n=e.node;local d=e.details or A.Resources.SkillDetails(n,skills,context)
  local icon=tostring(A.Resources.Icon(n)):gsub('|','')
  GameTooltip:AddLine('|T'..icon..':16|t '..safe(n.name or 'Known resource')..(e.count and ('  x'..e.count) or ''),1,1,1)
  GameTooltip:AddLine(safe(d.requirement),.85,.85,.8)
  GameTooltip:AddLine(safe(d.summary),unpack(d.color))
  if d.transition then GameTooltip:AddLine(safe(d.transition),unpack(A.Resources.colors[d.nextKey] or A.Resources.colors.unknown)) end
  if d.contextNote then GameTooltip:AddLine(safe(d.contextNote),.65,.65,.65,true) end
  if e.provenance then GameTooltip:AddLine(safe(e.provenance),.7,.7,.7,true) end
 end
 if extra then GameTooltip:AddLine(safe(extra),.7,.7,.65,true) end
 GameTooltip:Show()
end
function T.Entries(nodes)
 local entries,byID={},{}
 for _,n in ipairs(nodes) do
  local key=n.kind..':'..n.materialID;local e=byID[key]
  if not e then e={node=n,count=0,confirmed=0,imported=0};byID[key]=e;entries[#entries+1]=e end
  e.count=e.count+1;if n.confirmed then e.confirmed=e.confirmed+1 end;if n.imported then e.imported=e.imported+1 end
 end
 table.sort(entries,function(a,b) return (a.node.name or a.node.materialID)<(b.node.name or b.node.materialID) end)
 for _,e in ipairs(entries) do e.provenance=e.confirmed..' personal / '..e.imported..' imported locations' end
 return entries
end
function T.Bind(owner,title,getEntries,extra)
 owner:HookScript('OnEnter',function(self) T.Show(self,type(title)=='function' and title() or title,getEntries(),type(extra)=='function' and extra() or extra) end)
 owner:HookScript('OnLeave',function() if GameTooltip then GameTooltip:Hide() end end)
 owner:HookScript('OnHide',function() if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(owner) then GameTooltip:Hide() end end)
end
