local _,A=...
local M={};A.FarmingSession=M
function M.Key(n) return type(n.key)=='string' and n.key or string.format('%.17g:%.17g:%s',n.x,n.y,tostring(n.materialID)) end
function M.Signature(filter)
 filter=filter or {};local ids={}
 for id,on in pairs(filter.materials or {}) do if on then ids[#ids+1]=id end end;table.sort(ids)
 return (filter.source or 'combined')..'/'..(filter.kind or 'both')..'/'..(filter.materials and table.concat(ids,';') or '*')
end
function M.New(nodes,position,distance,options)
 options=options or {}
 local route,reason=A.Planner.Generate(nodes,position,distance,options);if not route then return nil,reason end
 local self={candidates=A.Store.Copy(nodes),route=route,message=reason,excluded={},undo={},distance=distance,options=A.Store.Copy(options),mapID=position.mapID,revision=1,review=true,signature=M.Signature(options.filter)}
 function self:Matches(filter) return self.signature==M.Signature(filter) end
 function self:Rebuild(p)
  local candidates={};for _,n in ipairs(self.candidates) do if not self.excluded[M.Key(n)] then candidates[#candidates+1]=n end end
  self.route,self.message=A.Planner.Generate(candidates,p,self.distance,self.options);self.revision=self.revision+1
  return self.route,self.message
 end
 local function available(p) return A.Store.Position(p) and p.mapID==self.mapID end
 function self:Remove(key,p)
  if not available(p) then return nil,'Return to the route zone with readable coordinates before changing nodes.' end
  if self.excluded[key] then return nil,'That node is already removed.' end
  local found=false;for _,n in ipairs(self.candidates) do if M.Key(n)==key then found=true;break end end
  if not found then return nil,'Select a node on the current route map.' end
  self.excluded[key]=true;self.undo[#self.undo+1]=key;self.selected=nil;self:Rebuild(p);return true
 end
 function self:Undo(p)
  if not available(p) then return nil,'Return to the route zone with readable coordinates before changing nodes.' end
  local key=self.undo[#self.undo];if not key then return nil,'No removal to undo.' end
  table.remove(self.undo);self.excluded[key]=nil;self.selected=nil;self:Rebuild(p);return true
 end
 return self,reason
end
