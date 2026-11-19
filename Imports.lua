local _, A = ...
local I={}; A.Imports=I
function I.Scan(db,provider)
 if not provider then return 0,'GatherMate2 is not available. Personal recording still works.' end
 local count=0
 local write=A.Store.ImportWriter(db,A.Client and A.Client.Size)
 local ok,err=pcall(function()
  for _,o in provider() do if type(o)=='table' then o=A.Store.Copy(o); o.source='imported'; if write(o) then count=count+1 end end end
 end)
 return count,ok and ('Imported '..count..' locations (no personal confirmations).') or ('Importer stopped: '..tostring(err))
end
function I.Provider(mapID)
 local gm=GatherMate2
 if not gm or type(gm.GetNodesForZone)~='function' or type(gm.DecodeLoc)~='function' or type(gm.GetNameForNode)~='function' then return nil end
 local stats={scanned=0,unknown=0,direct=0,fallback=0}
 if type(GatherMateData2HerbDB)~='table' and type(GatherMateData2MineDB)~='table' then
  if C_AddOns and C_AddOns.LoadAddOn then
   local ok,loaded,reason=pcall(C_AddOns.LoadAddOn,'GatherMate2_Data')
   if not ok then stats.loadError='LOAD_FAILED' elseif not loaded then stats.loadError=type(reason)=='string' and reason or 'UNAVAILABLE' end
  else stats.loadError='Loader unavailable' end
 end
 local roots={['Herb Gathering']=GatherMateData2HerbDB,Mining=GatherMateData2MineDB}
 stats.rawAvailable=type(roots['Herb Gathering'])=='table' or type(roots.Mining)=='table'
 local jobs={}
 for _,entry in ipairs({{'Herb Gathering','herb'},{'Mining','ore'}}) do
  local dbtype,kind=entry[1],entry[2]; local zones={}; local raw=roots[dbtype]
  local storage=gm.gmdbs and gm.gmdbs[dbtype]
  local function enumerate(t)
   if type(t)=='table' then for zone,rows in pairs(t) do if A.Store.Number(zone) and zone>0 and zone%1==0 and type(rows)=='table' then zones[zone]=true end end end
  end
  if mapID then zones[mapID]=true else
   enumerate(raw); enumerate(storage)
   if type(storage)=='table' then
    enumerate(storage.__gm2_base_storage)
    if type(storage.__gm2_storage_map)=='table' then for _,db in pairs(storage.__gm2_storage_map) do enumerate(db) end end
   end
   if type(gm.db_storage_map)=='table' then for zone in pairs(gm.db_storage_map) do if A.Store.Number(zone) and zone>0 and zone%1==0 then zones[zone]=true end end end
  end
  local ids={}; for zone in pairs(zones) do ids[#ids+1]=zone end; table.sort(ids)
  for _,zone in ipairs(ids) do
   local rows=type(raw)=='table' and raw[zone]; local direct=type(rows)=='table' and next(rows)~=nil
   if direct or storage then jobs[#jobs+1]={mapID=zone,dbtype=dbtype,kind=kind,rows=direct and rows or nil} end
  end
 end
 -- Capture source table references, stream every zone and yield even rejected
 -- rows. The consumer budgets work per update; no global truncation is applied.
 local provider=function()
  local ji=0; local iter,state,key; local job;local names={}
  return function()
   while true do
    if not iter then
     ji=ji+1; job=jobs[ji]; if not job then return end
     if job.rows then iter,state,key=pairs(job.rows) else iter,state,key=gm:GetNodesForZone(job.mapID,job.dbtype,true) end
    end
    local loc,id=iter(state,key); key=loc
    if loc==nil then iter=nil else
     stats.scanned=stats.scanned+1
     if A.Store.Number(loc) and A.Store.Number(id) then
      local x,y=gm:DecodeLoc(loc);local cache=names[job.dbtype] or {};names[job.dbtype]=cache
      local name=cache[id]
      if name==nil then name=gm:GetNameForNode(job.dbtype,id);cache[id]=type(name)=='string' and name or false end
      if type(name)=='string' then
       local source=job.rows and 'direct' or 'fallback'; stats[source]=stats[source]+1
       return stats.scanned,{mapID=job.mapID,x=x,y=y,kind=job.kind,materialID='gm:'..job.kind..':'..id,name=name}
      end
     end
     stats.unknown=stats.unknown+1; return stats.scanned,false
    end
   end
  end
 end
 return provider,stats
end
