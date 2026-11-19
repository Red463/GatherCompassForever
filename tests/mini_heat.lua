local function setup() dofile('tests/wow.lua');fakeUI();local A={};for _,n in ipairs({'Store','Client','Heatmap','MiniHeat'}) do module(n,A) end;return A end
test('minimap heat palette changes only cell RGB and preserves density opacity and masking',function()
 local A=setup();module('Resources',A)
 local route={width=1000,height=500,points={point(.3),point(.7)}}
 local field=A.MiniHeat.Field(route,function(p) return (p.x-.5)*500,0 end,200,200,'ROUND',{},.65,function(r) return r*.5,r*.5 end)
 local pool={};A.MiniHeat.Draw(pool,Minimap,field,'ROUND');local alpha=pool[1].color[4]
 for _,choice in ipairs(A.Resources.HeatColours) do
  A.MiniHeat.Draw(pool,Minimap,field,'ROUND',choice.rgb)
  near(pool[1].color[4],alpha);eq(#pool,#field);eq(#pool[1].masks,1)
  if choice.rgb then for channel=1,3 do near(pool[1].color[channel],choice.rgb[channel]) end
  else near(pool[1].color[1],1);near(pool[1].color[2],field[1].green);near(pool[1].color[3],.06) end
 end
end)
test('minimap heat uses bounded nonoverlapping cells with safe opacity and tracking clearance',function()
 local A=setup();local r={mapID=1,width=1000,height=500,points={point(.1),point(.4)},loop=true}
 local field=A.MiniHeat.Field(r,function(p) return (p.x-.2)*500,0 end,200,200,'ROUND',{{x=0,y=0,r=8},{x=40,y=0,r=7}},.35,function(radius) return radius*.5,radius*.5 end)
 assert(#field>0 and #field<=1600)
 for _,c in ipairs(field) do
  assert(c.alpha>0 and c.alpha<=.35);assert(A.MiniHeat.InShape(c.x,c.y,200,200,'ROUND'));assert(A.MiniHeat.InShape(c.x+c.width,c.y-c.height,200,200,'ROUND'))
  for _,hole in ipairs({{x=0,y=0,r=8},{x=40,y=0,r=7}}) do local dx=math.max(c.x-hole.x,0,hole.x-c.x-c.width);local dy=math.max(c.y-c.height-hole.y,0,hole.y-c.y);assert(dx*dx+dy*dy>=hole.r*hole.r) end
 end
 local pool={};A.MiniHeat.Draw(pool,Minimap,field,'ROUND');assert(#pool<=1600);assert(pool[1].masks and #pool[1].masks==1);A.MiniHeat.Hide(pool);eq(pool[1]:IsShown(),false)
 eq(#A.MiniHeat.Field(r,function() return 0,0 end,200,200,'UNKNOWN',{},1,function() return 50,50 end),0)
end)
test('minimap shape quadrants and ignored rotation match their native projection',function()
 local A=setup();eq(A.MiniHeat.InShape(-99,99,200,200,'SQUARE'),true);eq(A.MiniHeat.InShape(-99,99,200,200,'ROUND'),false)
 eq(A.MiniHeat.InShape(-99,99,200,200,'CORNER-TOPLEFT'),false);eq(A.MiniHeat.InShape(99,-99,200,200,'CORNER-TOPLEFT'),true)
 GetCVar=function() return '1' end;A.Client.Facing=function() return 1.2 end;C_Minimap={IsRotateMinimapIgnored=function() return true end,GetViewRadius=function() error('unavailable') end}
 eq(A.Client.MinimapFacing(),0);eq(A.Client.MinimapRadius(),nil);C_Minimap.IsRotateMinimapIgnored=function() return false end;near(A.Client.MinimapFacing(),1.2)
 A.Client.Facing=function() return nil end;eq(A.Client.MinimapFacing(),nil);C_Minimap=nil;GetCVar=nil
end)

test('minimap heat keeps a continuous dense corridor with soft player clearance',function()
 local A=setup();local route={width=1000,height=500,points={point(.3),point(.7)}}
 local field=A.MiniHeat.Field(route,function(p) return (p.x-.5)*500,0 end,200,200,'SQUARE',{{x=0,y=0,r=4,feather=5}},1,function(r) return r*.5,r*.5 end)
 local plain=A.MiniHeat.Field(route,function(p) return (p.x-.5)*500,0 end,200,200,'SQUARE',{},1,function(r) return r*.5,r*.5 end)
 local original={};for _,c in ipairs(plain) do original[c.x..':'..c.y]=c.alpha end
 local soft=false;local centre=false
 for _,c in ipairs(field) do if math.abs(c.y)<10 and math.abs(c.x)<90 then centre=true end;if c.alpha>0 and c.alpha<(original[c.x..':'..c.y] or 0) then soft=true end;assert(c.alpha<=.72) end
 assert(centre);assert(soft,'Player clearance has no feathered edge')
end)
