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
 local self={candidates=A.Store.Copy(nodes),route=route,message=reason,excluded={},undo={},distance=distance,options=A.Store.Copy(options),mapID=position.mapID,revision=1,review=true,signature=M.Signature(options.filter),byKey={}}
 for _,n in ipairs(self.candidates) do self.byKey[M.Key(n)]=n end
 function self:Matches(filter) return self.signature==M.Signature(filter) end
 local function proposed(excluded,p)
  local candidates={};for _,n in ipairs(self.candidates) do if not excluded[M.Key(n)] then candidates[#candidates+1]=n end end
  if #candidates==0 then return nil,'No nodes remain in this plan. Undo a removal or generate again.',true end
  local nextRoute,message=A.Planner.Generate(candidates,p,self.distance,self.options)
  return nextRoute,message,nextRoute~=nil
 end
 local function commit(route,message,excluded)
  self.route=route;self.message=message;self.excluded=excluded;self.selected=nil;self.revision=self.revision+1
 end
 function self:Rebuild(p)
  local route,message,ok=proposed(self.excluded,p)
  if ok then commit(route,message,self.excluded) end
  return route,message
 end
 local function available(p) return A.Store.Position(p) and p.mapID==self.mapID end
 function self:Propose(method,key,p)
  if not available(p) then return nil,'Return to the route zone with readable coordinates before changing nodes.' end
  local revision=self.revision
  local excluded=A.Store.Copy(self.excluded);local undo=A.Store.Copy(self.undo)
  if method=='Remove' then
   if excluded[key] then return nil,'That node is already removed.' end
   if not key or not self.byKey[key] then return nil,'Select a node on the current route map.' end
   excluded[key]=true;undo[#undo+1]=key
  elseif method=='Undo' then
   key=undo[#undo];if not key then return nil,'No removal to undo.' end
   excluded[key]=nil;table.remove(undo)
  else return nil,'Unknown plan change.' end
  local route,message,ok=proposed(excluded,p);if not ok then return nil,message end
  return {route=route,message=message,excluded=excluded,undo=undo,baseRevision=revision}
 end
 function self:CommitProposal(proposal)
  if type(proposal)~='table' or proposal.baseRevision~=self.revision then return nil,'The plan changed while this route was being calculated. Try again.' end
  commit(proposal.route,proposal.message,proposal.excluded);self.undo=proposal.undo;return true
 end
 function self:Remove(key,p)
  local proposal,reason=self:Propose('Remove',key,p);if not proposal then return nil,reason end
  return self:CommitProposal(proposal)
 end
 function self:Undo(p)
  local proposal,reason=self:Propose('Undo',nil,p);if not proposal then return nil,reason end
  return self:CommitProposal(proposal)
 end
 return self,reason
end
