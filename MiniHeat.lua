local _,A=...
local H={};A.MiniHeat=H
local names={'ROUND','SQUARE','CORNER-TOPLEFT','CORNER-TOPRIGHT','CORNER-BOTTOMLEFT','CORNER-BOTTOMRIGHT','SIDE-LEFT','SIDE-RIGHT','SIDE-TOP','SIDE-BOTTOM','TRICORNER-TOPLEFT','TRICORNER-TOPRIGHT','TRICORNER-BOTTOMLEFT','TRICORNER-BOTTOMRIGHT'}
local quadrants={{true,true,true,true},{false,false,false,false},{true,false,false,false},{false,false,true,false},{false,true,false,false},{false,false,false,true},{true,true,false,false},{false,false,true,true},{true,false,true,false},{false,true,false,true},{true,true,true,false},{true,false,true,true},{true,true,false,true},{false,true,true,true}}
local index={};for i,name in ipairs(names) do index[name]=i end
local kernelEdge,weightScale=math.exp(-4),math.log(20)
function H.InShape(x,y,w,h,shape)
 local slot=index[shape];if not slot or w<=0 or h<=0 then return false end
 if math.abs(x)>w/2 or math.abs(y)>h/2 then return false end
 local q=x<0 and (y>=0 and 1 or 2) or (y>=0 and 3 or 4)
 return not quadrants[slot][q] or (x/(w/2))^2+(y/(h/2))^2<=1
end
function H.Field(route,project,w,h,shape,holes,opacity,radiusProjection,workspace)
 local field=workspace and workspace.field or {}
 if workspace then
  field=field or {};workspace.field=field
  for i=#field,1,-1 do field[i]=nil end
 end
 if not index[shape] or not A.Store.Number(w) or not A.Store.Number(h) or math.min(w,h)<=0 or not A.Store.Number(opacity) or opacity<=0 then return field end
 -- Thin strips with shared horizontal edge samples avoid the visible square
 -- plateaus of the old 40 x 40 constant-colour grid. At most 3,072 textures.
 local cols,rows=math.min(32,math.max(1,math.ceil(w/8))),math.min(96,math.max(1,math.ceil(h/2)))
 local cw,ch=w/cols,h/rows;local stride=cols+1
 local density,fade,cells
 if workspace then
  density,fade,cells=workspace.density or {},workspace.fade or {},workspace.cells or {}
  for i=1,workspace.vertexCount or 0 do density[i]=nil end
  for i=1,workspace.cellCount or 0 do fade[i]=nil end
  workspace.density,workspace.fade,workspace.cells=density,fade,cells
  workspace.vertexCount,workspace.cellCount=stride*rows,cols*rows
 else density,fade={},{} end
 local samples=A.Heatmap.Samples(route)
 if samples.invalid then return field end
 local rx,ry=radiusProjection(samples.radius)
 if not A.Store.Number(rx) or not A.Store.Number(ry) or math.min(rx,ry)<=0 then return field end
 local function clamp(v,lo,hi) return math.max(lo,math.min(hi,v)) end
 for _,hole in ipairs(holes or {}) do
  local left,right=clamp(math.floor((hole.x-hole.r-(hole.feather or 4)+w/2)/cw),0,cols-1),clamp(math.floor((hole.x+hole.r+(hole.feather or 4)+w/2)/cw),0,cols-1)
  local top,bottom=clamp(math.floor((h/2-hole.y-hole.r-(hole.feather or 4))/ch),0,rows-1),clamp(math.floor((h/2-hole.y+hole.r+(hole.feather or 4))/ch),0,rows-1)
  for row=top,bottom do for col=left,right do
   local x,y=-w/2+col*cw,h/2-row*ch
   local dx=math.max(x-hole.x,0,hole.x-x-cw);local dy=math.max(y-ch-hole.y,0,hole.y-y)
   local key=row*cols+col+1;local amount=clamp((math.sqrt(dx*dx+dy*dy)-hole.r)/(hole.feather or 4),0,1)
   amount=amount*amount*(3-2*amount);fade[key]=math.min(fade[key] or 1,amount)
  end end
 end
 for _,p in ipairs(samples) do
  local px,py=project(p)
  if A.Store.Number(px) and A.Store.Number(py) and px+rx>=-w/2 and px-rx<=w/2 and py+ry>=-h/2 and py-ry<=h/2 then
   local left,right=clamp(math.floor((px-rx+w/2)/cw),0,cols),clamp(math.floor((px+rx+w/2)/cw),0,cols)
   local top,bottom=clamp(math.floor((h/2-py-ry)/ch),0,rows-1),clamp(math.floor((h/2-py+ry)/ch),0,rows-1)
   local weight=.35+math.min(1,math.log(1+(p.density or 1))/weightScale)
   for row=top,bottom do for col=left,right do
    local key=row*stride+col+1
    local dx=(-w/2+col*cw-px)/rx;local dy=(h/2-(row+.5)*ch-py)/ry;local q=dx*dx+dy*dy
    if q<1 then density[key]=(density[key] or 0)+weight*(math.exp(-q*4)-kernelEdge) end
   end end
  end
 end
 for row=0,rows-1 do for col=0,cols-1 do
  local dl,dr=density[row*stride+col+1] or 0,density[row*stride+col+2] or 0;local x,y=-w/2+col*cw,h/2-row*ch
  if math.max(dl,dr)>.005 and (fade[row*cols+col+1] or 1)>0 and H.InShape(x,y,w,h,shape) and H.InShape(x+cw,y,w,h,shape) and H.InShape(x,y-ch,w,h,shape) and H.InShape(x+cw,y-ch,w,h,shape) then
   -- A bright amber core stays readable over dark terrain; the density field
   -- and feathering still fade its edges and keep tracking clearance soft.
   local il,ir=1-math.exp(-dl*1.5),1-math.exp(-dr*1.5)
   local strength=.72*math.min(1,opacity)*(fade[row*cols+col+1] or 1)
   local i=#field+1;local cell=cells and cells[i] or {}
   if cells then cells[i]=cell end
   cell.x,cell.y,cell.width,cell.height=x,y,cw,ch
   cell.alpha,cell.green=(il+ir)/2*strength,.48+.18*(il+ir)/2
   cell.alphaLeft,cell.alphaRight,cell.greenLeft,cell.greenRight=il*strength,ir*strength,.48+.18*il,.48+.18*ir
   field[i]=cell
  end
 end end
 return field
end
function H.Hide(pool) for _,t in ipairs(pool) do t:Hide() end end
local function legacy(t,r,gl,gr,b,al,ar) t:SetGradientAlpha('HORIZONTAL',r,gl,b,al,r,gr,b,ar) end
local function color(t,key,r,g,b,a)
 local c=t[key]
 if not c then c=CreateColor(r,g,b,a);t[key]=c
 elseif type(c.SetRGBA)=='function' then c:SetRGBA(r,g,b,a)
 else c.r,c.g,c.b,c.a=r,g,b,a end
 return c
end
local function modern(t,r,gl,gr,b,al,ar) t:SetGradient('HORIZONTAL',color(t,'heatLeftColor',r,gl,b,al),color(t,'heatRightColor',r,gr,b,ar)) end
local function paint(pool,t,c,colour)
 local r,b=colour and colour[1] or 1,colour and colour[3] or .06
 local gl,gr=colour and colour[2] or c.greenLeft or c.green,colour and colour[2] or c.greenRight or c.green
 local al,ar=c.alphaLeft or c.alpha,c.alphaRight or c.alpha
 local p=t.heatPaint
 if p and p.r==r and p.gl==gl and p.gr==gr and p.b==b and p.al==al and p.ar==ar then return end
 p=p or {};p.r,p.gl,p.gr,p.b,p.al,p.ar=r,gl,gr,b,al,ar;t.heatPaint=p
 t:SetColorTexture(1,1,1,1)
 if not pool.gradientMode then
  -- Probe once per pool: Forever builds may expose either gradient API.
  if type(t.SetGradientAlpha)=='function' and pcall(legacy,t,r,gl,gr,b,al,ar) then pool.gradientMode='legacy';return end
  if type(t.SetGradient)=='function' and type(CreateColor)=='function' and pcall(modern,t,r,gl,gr,b,al,ar) then pool.gradientMode='modern';return end
  pool.gradientMode='flat'
 end
 if pool.gradientMode=='legacy' then legacy(t,r,gl,gr,b,al,ar)
 elseif pool.gradientMode=='modern' then modern(t,r,gl,gr,b,al,ar)
 else t:SetVertexColor(1,1,1,1);t:SetColorTexture(r,(gl+gr)/2,b,(al+ar)/2) end
end
function H.Draw(pool,parent,field,shape,colour)
 H.Hide(pool);local slot=index[shape];if not slot then return end
 if not pool.mask and type(parent.CreateMaskTexture)=='function' then
  local ok,mask=pcall(parent.CreateMaskTexture,parent,nil,'ARTWORK')
  if ok and mask then pool.mask=mask;mask:SetAllPoints(parent);mask:SetTexture('Interface\\AddOns\\Gatherly\\Media\\MinimapMasks') end
 end
 if pool.mask then local col,row=(slot-1)%4,math.floor((slot-1)/4);pool.mask:SetTexCoord(col/4,(col+1)/4,row/4,(row+1)/4) end
 for i,c in ipairs(field) do
  local t=pool[i]
  if not t then
   t=parent:CreateTexture(nil,'BACKGROUND',nil,1);pool[i]=t;if pool.mask and t.AddMaskTexture then t:AddMaskTexture(pool.mask) end
   if type(t.SetSnapToPixelGrid)=='function' then pcall(t.SetSnapToPixelGrid,t,false) end
   if type(t.SetTexelSnappingBias)=='function' then pcall(t.SetTexelSnappingBias,t,0) end
  end
  paint(pool,t,c,colour)
  local rect=t.heatRect
  if not rect or rect.parent~=parent or rect.x~=c.x or rect.y~=c.y or rect.width~=c.width or rect.height~=c.height then
   t:ClearAllPoints();t:SetPoint('TOPLEFT',parent,'CENTER',c.x,c.y);t:SetSize(c.width,c.height)
   rect=rect or {};rect.parent,rect.x,rect.y,rect.width,rect.height=parent,c.x,c.y,c.width,c.height;t.heatRect=rect
  end
  t:Show()
 end
end
