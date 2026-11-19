local _, A = ...
A.Planner={}
local function clip(text,limit)
 if #text<=limit then return text end
 local last=limit
 while last>0 do local byte=text:byte(last+1);if not byte or byte<128 or byte>=192 then break end;last=last-1 end
 return text:sub(1,last):gsub('%s+$','')
end
function A.Planner.Name(nodes,mapID,options)
 options=options or {}
 local zone=type(options.zoneName)=='string' and options.zoneName:match('%S') and options.zoneName or 'Zone '..mapID
 local resources,seen={},{};local herbs,ore=false,false
 for _,node in ipairs(nodes) do
  herbs=herbs or node.kind=='herb';ore=ore or node.kind=='ore'
  local info=A.Resources and A.Resources.Info(node)
  local name=info and info.name or node.name
  local key=tostring(node.kind)..':'..tostring(info and info.id or node.materialID or name)
  if type(name)=='string' and name:find('%S') and not seen[key] then seen[key]=true;resources[#resources+1]=name end
 end
 table.sort(resources,function(a,b) return a:lower()<b:lower() end)
 local category=herbs and ore and 'Herbs & Ore' or herbs and 'Herbalism' or ore and 'Mining' or 'Gathering'
 local subject=not (herbs and ore) and #resources>0 and #resources<=2 and table.concat(resources,' & ') or category
 if #zone+#subject+8>80 then subject=category end
 local body=' - '..subject..' Loop'
 local function make(suffix) return clip(zone,80-#body-#suffix)..body..suffix end
 local taken={}
 for _,route in pairs(options.routes or {}) do if type(route.name)=='string' then taken[route.name:lower()]=true end end
 local name=make('');local number=2
 while taken[name:lower()] do name=make(' ('..number..')');number=number+1 end
 return name
end
function A.Planner.Generate(nodes,start,distance,options)
 options=options or {}; if not A.Store.Position(start) then return nil,'A readable player position is required.' end
 local chosen={}; local limited=false
 -- Bound input scan too. Store.Select already applies provenance/material filters.
 for i=1,math.min(#nodes,10000) do
  local n=nodes[i]
  if A.Store.Position(n) and n.mapID==start.mapID then
   if #chosen>=300 then limited=true; break end
   chosen[#chosen+1]=n
  end
 end
 if #nodes>10000 then limited=true end
 local clusters={}
 for _,n in ipairs(chosen) do
  local merged=false
  for _,p in ipairs(clusters) do local d=distance(n,p); if not d then return nil,'Zone distance data is unavailable.' end; if n.materialID==p.materialID and d<=10 then merged=true; break end end
  if not merged then clusters[#clusters+1]=n end
 end
 if #clusters==0 then return nil,'No spawn points match these filters in this zone.' end
 local order={}; local cursor=start
 while #clusters>0 do
  local best,bd
  for i,n in ipairs(clusters) do local d=distance(cursor,n); if not d then return nil,'Zone distance data is unavailable.' end; if not bd or d<bd then best,bd=i,d end end
  local n=table.remove(clusters,best); order[#order+1]=n; cursor=n
 end
 local comparisons=0
 for i=1,#order-2 do
  for j=i+2,#order do
   if comparisons>=10000 then break end
   comparisons=comparisons+1
   local a,b=order[i],order[i+1]; local c,d=order[j],order[j%#order+1]
   if distance(a,c)+distance(b,d)<distance(a,b)+distance(c,d) then
    local l,r=i+1,j; while l<r do order[l],order[r]=order[r],order[l]; l=l+1; r=r-1 end
   end
  end
  if comparisons>=10000 then break end
 end
 local points={}
 for _,n in ipairs(order) do points[#points+1]={mapID=start.mapID,x=n.x,y=n.y,kind='gather',nodeKey=n.key,name=n.name} end
 return {name=options.name or A.Planner.Name(order,start.mapID,options),mapID=start.mapID,loop=true,generated=true,points=points},limited and 'Limited to the first 300 matching candidates; narrow your filters for better coverage.' or nil
end
