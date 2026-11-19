local _,A=...
local O={};A.MapOverlays=O
local function padded(value) local n=16;while n<value do n=n*2 end;return n end
local function read(fn,...)
 if type(fn)~='function' then return end
 local ok,value=pcall(fn,...);if ok then return value end
end
function O.New()
 local self={events=CreateFrame('Frame')}
 self.events:RegisterEvent('MAP_EXPLORATION_UPDATED');self.events:SetScript('OnEvent',function() self.cache=nil end)
 function self:Get(mapID,artID,layer)
  local fn=C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
  local signature=tostring(mapID)..':'..tostring(artID)..':'..layer.tileWidth..':'..layer.tileHeight..':'..tostring(fn)
  if self.cache and self.signature==signature then return self.cache,self.covered end
  self.cache=nil
  local native=read(fn,mapID);local metadata=A.MapReveal and A.MapReveal[artID]
  local pieces,seen={},{};local covered=type(metadata)=='table';local tw,th=layer.tileWidth,layer.tileHeight
  local function add(w,h,x,y,files,top,hover)
   if not (A.Store.Number(w) and A.Store.Number(h) and A.Store.Number(x) and A.Store.Number(y)) then return false end
   for _,n in ipairs({w,h,x,y}) do if not A.Store.Number(n) or n%1~=0 then return false end end
   if w<=0 or h<=0 or x<0 or y<0 or type(files)~='table' then return false end
   local key=w..':'..h..':'..x..':'..y
   if seen[key] then return true end
   if hover then seen[key]=true;return true end
   local cols,rows=math.ceil(w/tw),math.ceil(h/th)
   if cols*rows>256 or #pieces+cols*rows>1024 then return false end
   for i=1,cols*rows do if not A.Store.Number(files[i]) or files[i]<=0 then return false end end
   seen[key]=true;local complete=true
   for row=0,rows-1 do for col=0,cols-1 do
    local file=files[row*cols+col+1];local width,height=math.min(tw,w-col*tw),math.min(th,h-row*th)
    if A.Store.Number(file) and file>0 then
     pieces[#pieces+1]={file=file,x=x+col*tw,y=y+row*th,width=width,height=height,fileWidth=col==cols-1 and padded(width) or tw,fileHeight=row==rows-1 and padded(height) or th,top=top}
    else complete=false end
   end end
   return complete
  end
  if type(native)=='table' then for _,e in ipairs(native) do if type(e)=='table' then add(e.textureWidth,e.textureHeight,e.offsetX,e.offsetY,e.fileDataIDs,e.isDrawOnTopLayer,e.isShownByMouseOver) end end end
  if type(metadata)=='table' then
   local keys={};for key in pairs(metadata) do if type(key)=='string' then keys[#keys+1]=key else covered=false end end;table.sort(keys)
   for _,key in ipairs(keys) do
    local w,h,x,y=key:match('^(%d+):(%d+):(%d+):(%d+)$');local ids={}
    if type(metadata[key])=='string' then for id in metadata[key]:gmatch('%d+') do ids[#ids+1]=tonumber(id) end end
    if not w or not add(tonumber(w),tonumber(h),tonumber(x),tonumber(y),ids) then covered=false end
   end
  end
  self.signature=signature;self.covered=covered
  if type(native)=='table' or type(fn)~='function' then self.cache=pieces end
  return pieces,covered
 end
 return self
end
