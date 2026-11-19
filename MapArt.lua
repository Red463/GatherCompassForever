local _,A=...
local M={};A.MapArt=M
function M.Project(p,b,w,h) return (p.x-b.left)/(b.right-b.left)*w,-(p.y-b.top)/(b.bottom-b.top)*h end
local function query(fn,...)
 if type(fn)~='function' then return end
 local ok,value=pcall(fn,...);if ok then return value end
end
function M.New(parent)
 local self={parent=parent,tiles={},overlays={},overlaySource=A.MapOverlays.New()};self.events=self.overlaySource.events
 function self:Draw(mapID,bounds,width,height)
  for _,t in ipairs(self.tiles) do t:Hide() end
  for _,t in ipairs(self.overlays) do t:Hide() end
  self.available=false;self.revealed=false;self.status=nil
  if not mapID or not C_Map then self.aspect=nil;return end
  local artID=query(C_Map.GetMapArtID,mapID)
  if not artID or self.mapID~=mapID or self.artID~=artID or not self.layer or type(self.textures)~='table' or not next(self.textures) or not C_Map.GetMapArtLayers then
   self.mapID=mapID;self.artID=artID;self.aspect=nil
   local layers=query(C_Map.GetMapArtLayers,mapID);self.layer=type(layers)=='table' and layers[1] or nil
   self.textures=self.layer and query(C_Map.GetMapArtLayerTextures,mapID,1) or nil
  end
  local layer=self.layer
  if not layer or type(self.textures)~='table' then return end
  local w,h,tw,th=layer.layerWidth,layer.layerHeight,layer.tileWidth,layer.tileHeight
  if not (A.Store.Number(w) and A.Store.Number(h) and A.Store.Number(tw) and A.Store.Number(th)) or math.min(w,h,tw,th)<=0 then return end
  local cols,rows=math.ceil(w/tw),math.ceil(h/th);if cols*rows>256 then return end
  self.aspect=w/h;local used=0
  for row=0,rows-1 do for col=0,cols-1 do
   local file=self.textures[row*cols+col+1]
   local left,top=col*tw/w,row*th/h;local right,bottom=math.min(1,(col+1)*tw/w),math.min(1,(row+1)*th/h)
   local x1,y1=math.max(left,bounds.left),math.max(top,bounds.top)
   local x2,y2=math.min(right,bounds.right),math.min(bottom,bounds.bottom)
   if file and x1<x2 and y1<y2 then
    used=used+1;local t=self.tiles[used]
    if not t then t=self.parent:CreateTexture(nil,'BACKGROUND',nil,-6);self.tiles[used]=t end
    local x,y=M.Project({x=x1,y=y1},bounds,width,height)
    t:SetTexture(file);t:ClearAllPoints();t:SetPoint('TOPLEFT',self.parent,'TOPLEFT',x,y)
    t:SetSize((x2-x1)/(bounds.right-bounds.left)*width,(y2-y1)/(bounds.bottom-bounds.top)*height)
    t:SetTexCoord((x1-left)*w/tw,(x2-left)*w/tw,(y1-top)*h/th,(y2-top)*h/th);t:Show()
   end
  end end
  self.available=used>0
  local pieces,covered=self.overlaySource:Get(mapID,artID,layer);self.revealed=covered
  self.status=not covered and 'Native map artwork (full-reveal data unavailable)' or nil
  local count=0
  for _,p in ipairs(pieces) do
   local left,top=p.x/w,p.y/h;local right,bottom=(p.x+p.width)/w,(p.y+p.height)/h
   local x1,y1=math.max(left,bounds.left,0),math.max(top,bounds.top,0)
   local x2,y2=math.min(right,bounds.right,1),math.min(bottom,bounds.bottom,1)
   if x1<x2 and y1<y2 then
    count=count+1;local t=self.overlays[count]
    if not t then t=self.parent:CreateTexture(nil,'BACKGROUND',nil,-4);self.overlays[count]=t end
    local x,y=M.Project({x=x1,y=y1},bounds,width,height)
    t:SetTexture(p.file);t:SetDrawLayer('BACKGROUND',p.top and -3 or -4);t:ClearAllPoints();t:SetPoint('TOPLEFT',self.parent,'TOPLEFT',x,y)
    t:SetSize((x2-x1)/(bounds.right-bounds.left)*width,(y2-y1)/(bounds.bottom-bounds.top)*height)
    t:SetTexCoord((x1-left)*w/p.fileWidth,(x2-left)*w/p.fileWidth,(y1-top)*h/p.fileHeight,(y2-top)*h/p.fileHeight);t:Show()
   end
  end
  self.available=self.available or count>0
 end
 return self
end
