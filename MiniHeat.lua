local _,A=...
local H={};A.MiniHeat=H
local names={'ROUND','SQUARE','CORNER-TOPLEFT','CORNER-TOPRIGHT','CORNER-BOTTOMLEFT','CORNER-BOTTOMRIGHT','SIDE-LEFT','SIDE-RIGHT','SIDE-TOP','SIDE-BOTTOM','TRICORNER-TOPLEFT','TRICORNER-TOPRIGHT','TRICORNER-BOTTOMLEFT','TRICORNER-BOTTOMRIGHT'}
local quadrants={{true,true,true,true},{false,false,false,false},{true,false,false,false},{false,false,true,false},{false,true,false,false},{false,false,false,true},{true,true,false,false},{false,false,true,true},{true,false,true,false},{false,true,false,true},{true,true,true,false},{true,false,true,true},{true,true,false,true},{false,true,true,true}}
local index={};for i,name in ipairs(names) do index[name]=i end
function H.InShape(x,y,w,h,shape)
 local slot=index[shape];if not slot or w<=0 or h<=0 then return false end
 if math.abs(x)>w/2 or math.abs(y)>h/2 then return false end
 local q=x<0 and (y>=0 and 1 or 2) or (y>=0 and 3 or 4)
 return not quadrants[slot][q] or (x/(w/2))^2+(y/(h/2))^2<=1
end
function H.Field(route,project,w,h,shape,holes,opacity,radiusProjection)
 local field={};if not index[shape] or not A.Store.Number(w) or not A.Store.Number(h) or math.min(w,h)<=0 or not A.Store.Number(opacity) or opacity<=0 then return field end
 local cols,rows=math.min(40,math.max(1,math.ceil(w/5))),math.min(40,math.max(1,math.ceil(h/5)))
 local cw,ch=w/cols,h/rows;local density,fade={},{};local samples=A.Heatmap.Samples(route);local rx,ry=radiusProjection(samples.radius)
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
   local left,right=clamp(math.floor((px-rx+w/2)/cw),0,cols-1),clamp(math.floor((px+rx+w/2)/cw),0,cols-1)
   local top,bottom=clamp(math.floor((h/2-py-ry)/ch),0,rows-1),clamp(math.floor((h/2-py+ry)/ch),0,rows-1)
   local weight=.35+math.min(1,math.log(1+(p.density or 1))/math.log(20))
   for row=top,bottom do for col=left,right do
    local key=row*cols+col+1
    if fade[key]~=0 then
     local dx=(-w/2+(col+.5)*cw-px)/rx;local dy=(h/2-(row+.5)*ch-py)/ry;local q=dx*dx+dy*dy
     if q<1 then density[key]=(density[key] or 0)+weight*(math.exp(-q*4)-math.exp(-4)) end
    end
   end end
  end
 end
 for row=0,rows-1 do for col=0,cols-1 do
  local d=density[row*cols+col+1];local x,y=-w/2+col*cw,h/2-row*ch
  if d and d>.005 and H.InShape(x,y,w,h,shape) and H.InShape(x+cw,y,w,h,shape) and H.InShape(x,y-ch,w,h,shape) and H.InShape(x+cw,y-ch,w,h,shape) then
   -- A bright amber core stays readable over dark terrain; the density field
   -- and feathering still fade its edges and keep tracking clearance soft.
   local intensity=1-math.exp(-d*1.5)
   field[#field+1]={x=x,y=y,width=cw,height=ch,alpha=intensity*.72*math.min(1,opacity)*(fade[row*cols+col+1] or 1),green=.48+.18*intensity}
  end
 end end
 return field
end
function H.Hide(pool) for _,t in ipairs(pool) do t:Hide() end end
function H.Draw(pool,parent,field,shape)
 H.Hide(pool);local slot=index[shape];if not slot then return end
 if not pool.mask and type(parent.CreateMaskTexture)=='function' then
  local ok,mask=pcall(parent.CreateMaskTexture,parent,nil,'ARTWORK')
  if ok and mask then pool.mask=mask;mask:SetAllPoints(parent);mask:SetTexture('Interface\\AddOns\\Gatherly\\Media\\MinimapMasks') end
 end
 if pool.mask then local col,row=(slot-1)%4,math.floor((slot-1)/4);pool.mask:SetTexCoord(col/4,(col+1)/4,row/4,(row+1)/4) end
 for i,c in ipairs(field) do
  local t=pool[i]
  if not t then t=parent:CreateTexture(nil,'BACKGROUND',nil,1);pool[i]=t;if pool.mask and t.AddMaskTexture then t:AddMaskTexture(pool.mask) end end
  t:SetColorTexture(1,c.green,.06,c.alpha);t:ClearAllPoints();t:SetPoint('TOPLEFT',parent,'CENTER',c.x,c.y);t:SetSize(c.width,c.height);t:Show()
 end
end
