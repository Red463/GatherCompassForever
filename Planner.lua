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
 return A.Corridor.Generate(nodes,start,distance,options)
end
