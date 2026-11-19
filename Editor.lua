local _, A = ...
A.Editor={}
function A.Editor.New(route)
 local e={draft=A.Store.Copy(route)}
 function e:Route() return A.Store.Copy(self.draft) end
 function e:Add(p)
  if not A.Store.Position(p) or p.mapID~=self.draft.mapID or #self.draft.points>=2000 then return false end
  self.draft.points[#self.draft.points+1]=A.Store.Copy(p); return true
 end
 function e:Move(i,p)
  if not self.draft.points[i] or not A.Store.Position(p) or p.mapID~=self.draft.mapID then return false end
  self.draft.points[i].x,self.draft.points[i].y=p.x,p.y; return true
 end
 function e:Delete(i) if self.draft.points[i] then table.remove(self.draft.points,i); return true end; return false end
 function e:Reorder(i,j)
  if not self.draft.points[i] or not self.draft.points[j] then return false end
  table.insert(self.draft.points,j,table.remove(self.draft.points,i)); return true
 end
 function e:Reverse()
  local p=self.draft.points; for i=1,math.floor(#p/2) do p[i],p[#p-i+1]=p[#p-i+1],p[i] end
 end
 function e:SetLoop(v) self.draft.loop=not not v end
 return e
end
