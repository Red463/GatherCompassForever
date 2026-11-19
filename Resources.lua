local _, A = ...
local R={}; A.Resources=R
local S=A.Store
local dbtype={herb='Herb Gathering',ore='Mining'}
local profession={herb=182,ore=186}
local fallback={herb='Interface\\Icons\\Trade_Herbalism',ore='Interface\\Icons\\Trade_Mining'}
-- Resource identities and Classic requirements only, no spawn dataset. These
-- are Classic reference data, not server-provided skill-up probabilities.
local catalog={herb={},ore={}}; local names={herb={},ore={}}
local function resource(kind,id,name,item,required,texture)
 local first=required==1 and 0 or required
 local row={id=id,name=name,item=item,required=required,yellow=first+25,green=first+50,grey=first+100,texture=texture}
 catalog[kind][id]=row; names[kind][name:lower()]=row
end
local herbs={
 {401,'Peacebloom',2447,1,'INV_Misc_Flower_02'}, {402,'Silverleaf',765,1,'INV_Misc_Herb_10'},
 {403,'Earthroot',2449,15,'INV_Misc_Herb_07'}, {404,'Mageroyal',785,50,'INV_Jewelry_Talisman_03'},
 {405,'Briarthorn',2450,70,'INV_Misc_Root_01'}, {406,'Swiftthistle',2452,nil},
 {407,'Stranglekelp',3820,85,'INV_Misc_Herb_11'}, {408,'Bruiseweed',2453,100,'INV_Misc_Herb_01'},
 {409,'Wild Steelbloom',3355,115,'INV_Misc_Flower_01'}, {410,'Grave Moss',3369,120,'INV_Misc_Dust_02'},
 {411,'Kingsblood',3356,125,'INV_Misc_Herb_03'}, {412,'Liferoot',3357,150,'INV_Misc_Root_02'},
 {413,'Fadeleaf',3818,160,'INV_Misc_Herb_12'}, {414,'Goldthorn',3821,170,'INV_Misc_Herb_15'},
 {415,"Khadgar's Whisker",3358,185,'INV_Misc_Herb_08'}, {416,'Wintersbite',3819,195,'INV_Misc_Flower_03'},
 {417,'Firebloom',4625,205,'INV_Misc_Herb_19'}, {418,'Purple Lotus',8831,210,'INV_Misc_Herb_17'},
 {420,"Arthas' Tears",8836,220,'INV_Misc_Herb_13'}, {421,'Sungrass',8838,230,'INV_Misc_Herb_18'},
 {422,'Blindweed',8839,235,'INV_Misc_Herb_14'}, {423,'Ghost Mushroom',8845,245,'INV_Mushroom_08'},
 {424,'Gromsblood',8846,250,'INV_Misc_Herb_16'}, {425,'Golden Sansam',13464,260,'INV_Misc_Herb_SansamRoot'},
 {426,'Dreamfoil',13463,270,'INV_Misc_Herb_DreamFoil'}, {427,'Mountain Silversage',13465,280,'INV_Misc_Herb_MountainSilverSage'},
 {428,'Plaguebloom',13466,285,'INV_Misc_Herb_PlagueBloom'}, {429,'Icecap',13467,290,'INV_Misc_Herb_IceCap'},
 {431,'Black Lotus',13468,300,'INV_Misc_Herb_BlackLotus'},
}
for _,v in ipairs(herbs) do if v[4] then resource('herb',unpack(v)) end end
local ores={
 {201,'Copper Vein',2770,1,'INV_Ore_Copper'}, {202,'Tin Vein',2771,65,'INV_Ore_Tin'},
 {203,'Iron Deposit',2772,125,'INV_Ore_Iron'}, {204,'Silver Vein',2775,75,'INV_Stone_16'},
 {205,'Gold Vein',2776,155,'INV_Ore_Gold_01'}, {206,'Mithril Deposit',3858,175,'INV_Ore_Mithril_02'},
 {208,'Truesilver Deposit',7911,230,'INV_Ore_TrueSilver_01'}, {214,'Small Thorium Vein',10620,245,'INV_Ore_Thorium_02'},
 {215,'Rich Thorium Vein',10620,275,'INV_Ore_Thorium_02'}, {217,'Dark Iron Deposit',11370,230,'INV_Ore_Mithril_01'},
}
for _,v in ipairs(ores) do resource('ore',unpack(v)) end
-- Variant identities are declared explicitly, rather than guessing from names.
for variant,base in pairs({[207]=206,[209]=204,[210]=205,[211]=208,[212]=215,[213]=214,[216]=215}) do catalog.ore[variant]=catalog.ore[base] end
function R.Info(node)
 if not node or not catalog[node.kind] then return nil end
 local id=type(node.materialID)=='string' and tonumber(node.materialID:match('^gm:'..node.kind..':(%d+)$'))
 local gm=GatherMate2
 if not id and gm and type(gm.GetIDForNode)=='function' and type(node.name)=='string' then
  local ok,value=pcall(gm.GetIDForNode,gm,dbtype[node.kind],node.name); if ok and S.Number(value) then id=value end
 end
 if id then return catalog[node.kind][id],id end
 local name=type(node.name)=='string' and node.name:lower()
 return name and names[node.kind][name] or nil
end
function R.Icon(node)
 local info,id=R.Info(node); local gm=GatherMate2
 if not id and info then id=info.id end
 local textures=gm and gm.nodeTextures and gm.nodeTextures[dbtype[node.kind]]
 if textures and id and type(textures[id])=='string' then return textures[id] end
 if info then
  local api=C_Item and C_Item.GetItemIconByID or GetItemIcon
  if type(api)=='function' then local ok,value=pcall(api,info.item); if ok and (type(value)=='string' or S.Number(value)) then return value end end
  if info.texture then return 'Interface\\Icons\\'..info.texture end
 end
 return fallback[node.kind] or 'Interface\\Icons\\INV_Misc_QuestionMark'
end
local function finite(v,default,lo,hi) if not S.Number(v) then return default end; return math.max(lo,math.min(hi,v)) end
function R.Settings(settings)
 local s=type(settings.nodeDisplay)=='table' and settings.nodeDisplay or {}; settings.nodeDisplay=s
 if s.outline~='ring' and s.outline~='square' and s.outline~='none' then s.outline='ring' end
 if type(s.icon)~='boolean' then s.icon=true end
 if s.outline=='none' and not s.icon then s.icon=true end
 if type(s.world)~='boolean' then s.world=true end; if type(s.mini)~='boolean' then s.mini=true end
 if type(s.routeLines)~='boolean' then s.routeLines=true end
 s.outlineSize=finite(s.outlineSize,24,20,40); s.iconSize=finite(s.iconSize,14,10,24); s.hideDistance=finite(s.hideDistance,20,0,100)
 if type(s.groupWorld)~='boolean' then s.groupWorld=true end;if type(s.groupMini)~='boolean' then s.groupMini=true end
 s.worldIconSize=finite(s.worldIconSize,s.iconSize,10,24);s.routeOpacity=finite(s.routeOpacity,.65,0,1)
 s.worldIconOpacity=finite(s.worldIconOpacity,1,0,1);s.miniIconOpacity=finite(s.miniIconOpacity,1,0,1);s.miniOutlineOpacity=finite(s.miniOutlineOpacity,1,0,1)
 s.worldLineOpacity=finite(s.worldLineOpacity,1,0,1)
 s.worldHeatOpacity=finite(s.worldHeatOpacity,.5,0,1)
 -- Seed each minimap style only when its own saved value is missing.
 s.miniLineOpacity=finite(s.miniLineOpacity,s.miniLineOpacity==nil and s.routeOpacity or .65,0,1)
 s.miniHeatOpacity=finite(s.miniHeatOpacity,s.miniHeatOpacity==nil and s.routeOpacity or .65,0,1)
 return s
end
local function call(fn,...)
 if type(fn)~='function' then return end
 local result={pcall(fn,...)}; if result[1] then return unpack(result,2) end
end
local oreItemNames={[2770]='Copper Ore',[2771]='Tin Ore',[2772]='Iron Ore',[2775]='Silver Ore',[2776]='Gold Ore',[3858]='Mithril Ore',[7911]='Truesilver Ore',[10620]='Thorium Ore',[11370]='Dark Iron Ore'}
function R.Catalog()
 local result={}
 for kind,rows in pairs(catalog) do for id,row in pairs(rows) do if id==row.id then
  local copy=S.Copy(row);copy.kind=kind;copy.materialID='gm:'..kind..':'..id
  copy.itemName=kind=='ore' and oreItemNames[row.item] or row.name;result[#result+1]=copy
 end end end
 table.sort(result,function(a,b) if a.kind~=b.kind then return a.kind<b.kind end;return a.id<b.id end)
 return result
end
function R.ItemName(source)
 local name=source.item and call(C_Item and C_Item.GetItemNameByID,source.item)
 local function readable(value) return not (issecretvalue and issecretvalue(value)) and type(value)=='string' and value:find('%S') end
 if not readable(name) and source.item then name=call(GetItemInfo,source.item) end
 if readable(name) then return name end
 for _,key in ipairs({'itemName','name','materialID'}) do if readable(source[key]) then return source[key] end end
 return 'Unknown resource'
end
function R.ItemIcon(source)
 local texture=source.item and call(C_Item and C_Item.GetItemIconByID or GetItemIcon,source.item)
 if not (issecretvalue and issecretvalue(texture)) and (type(texture)=='string' or S.Number(texture)) then return texture end
 return R.Icon(source)
end
local function readableName(spell,english)
 local name=call(C_Spell and C_Spell.GetSpellName or GetSpellInfo,spell)
 return type(name)=='string' and name or english
end
function R.Skills()
 local ranks,context={},{};local labels={herb=readableName(2366,'Herbalism'),ore=readableName(2575,'Mining')}
 local function record(kind,rank,maxRank,bonus,present)
  if present and not context[kind] then context[kind]={known=true} end
  if not ranks[kind] and S.Number(rank) and rank>0 then
   ranks[kind]=rank;context[kind]={maxRank=S.Number(maxRank) and maxRank>0 and maxRank or nil,bonus=S.Number(bonus) and bonus or nil}
  end
 end
 for kind,id in pairs(profession) do
  local info=call(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID,id)
  if type(info)=='table' then
   local bonus=S.Number(info.modifier) and S.Number(info.tempPoints) and info.modifier+info.tempPoints or nil
   record(kind,info.rank,info.maxRank,bonus)
  end
 end
 local complete=false
 if type(GetProfessions)=='function' and type(GetProfessionInfo)=='function' then
  local indices={pcall(GetProfessions)};local valid=indices[1]==true;local found=0
  for slot,index in pairs(indices) do if slot>1 and index~=nil then
   if not S.Number(index) then valid=false else
    local ok,name,_,rank,maxRank,_,_,line,bonus=pcall(GetProfessionInfo,index)
    name=A.Client.Read(name);line=A.Client.Read(line)
    if not ok or type(name)~='string' or not S.Number(line) then valid=false else
     found=found+1;for kind,id in pairs(profession) do if line==id or name==labels[kind] then record(kind,rank,maxRank,bonus,true) end end
    end
   end
  end end
  complete=valid and (found>0 or call(IsLoggedIn)==true)
 end
 local nativeCount=call(C_SkillInfo and C_SkillInfo.GetNumSkillLines)
 if S.Number(nativeCount) and nativeCount>0 and nativeCount<=200 then
  local valid=true
  for i=1,nativeCount do
   local row=call(C_SkillInfo and C_SkillInfo.GetSkillLineInfo,i)
   if type(row)~='table' or A.Client.Read(row.isHeader)==nil or A.Client.Read(row.isCollapsed)==nil then valid=false
   elseif row.isHeader then if row.isCollapsed then valid=false end
   elseif not S.Number(A.Client.Read(row.skillID)) then valid=false
   else
    for kind,id in pairs(profession) do if A.Client.Read(row.skillID)==id then
     local bonus=S.Number(row.modifier) and S.Number(row.tempPoints) and row.modifier+row.tempPoints or nil
     record(kind,row.rank,row.maxRank,bonus,true)
    end end
   end
  end
  complete=complete or valid
 end
 local count=call(GetNumSkillLines)
 if S.Number(count) then for i=1,math.min(count,200) do
  local name,header,_,rank,temporary,modifier,maxRank=call(GetSkillLineInfo,i)
  name=A.Client.Read(name);header=A.Client.Read(header)
  if not header then
   local bonus=S.Number(temporary) and S.Number(modifier) and temporary+modifier or nil
   for kind,label in pairs(labels) do if name==label then record(kind,rank,maxRank,bonus) end end
  end
 end end
 for kind in pairs(profession) do if ranks[kind] then context[kind].known=true elseif complete and not (context[kind] and context[kind].known) then context[kind]={known=false} end end
 return ranks,context
end
R.colors={orange={1,.5,.15},yellow={1,.85,.20},green={.30,.85,.35},grey={.50,.50,.50},red={.90,.25,.25},unknown={.9,.9,.85}}
function R.Difficulty(node,skills,context)
 local info=R.Info(node);local rank=skills and skills[node.kind];local key='unknown'
 local ctx=context and context[node.kind]
 if ctx and ctx.known==false then key='red'
 elseif info and S.Number(rank) then
  local bonus=ctx and ctx.bonus;local effective=rank+(S.Number(bonus) and bonus or 0)
  local capped=ctx and S.Number(ctx.maxRank) and rank>=ctx.maxRank
  key=effective<info.required and 'red' or capped and 'grey' or rank>=info.grey and 'grey' or rank>=info.green and 'green' or rank>=info.yellow and 'yellow' or 'orange'
 end
 local source=ctx and ctx.known==false and 'profession' or key=='unknown' and 'unknown' or 'reference'
 local label=source=='profession' and ((node.kind=='ore' and 'Mining' or 'Herbalism')..' not learned.') or key=='unknown' and 'Unknown: node thresholds or profession rank unavailable.' or
  ('Reference data (Classic): '..key..' (base skill '..rank..'; requires '..info.required..').')
 return R.colors[key],label,key,source
end
-- Structured guidance shares the exact thresholds used by minimap outlines.
function R.SkillDetails(node,skills,context)
 local color,_,key,source=R.Difficulty(node,skills,context)
 local info=R.Info(node);local rank=skills and skills[node.kind]
 if not S.Number(rank) then rank=nil end
 local ctx=context and context[node.kind] or {}
 local bonus=S.Number(ctx.bonus) and ctx.bonus or nil
 local maximum=S.Number(ctx.maxRank) and ctx.maxRank>0 and ctx.maxRank or nil
 local effective=rank and bonus and rank+bonus or nil
 local result={key=key,source=source,color=color,required=info and info.required,rank=rank,effectiveSkill=effective}
 if source=='profession' then local name=node.kind=='ore' and 'Mining' or 'Herbalism';result.requirement='Requires '..name;result.summary='Learn '..name..' to gather';return result end
 if info then result.requirement=string.format('Requires %d (%s)',info.required,rank and ('you have '..(effective or rank)) or 'skill unavailable')
 else result.requirement='Required skill unknown'..(rank and (' (you have '..rank..')') or '') end
 local descriptions={red="Can't gather yet",orange='High skill-up chance',yellow='Usually a skill-up',green='Sometimes a skill-up',grey='No more skill-ups here',unknown='Skill-up chance unknown'}
 result.summary=descriptions[key]
 local notes={}
 if rank and bonus and bonus~=0 then notes[#notes+1]=string.format('Base skill %d %+d bonus.',rank,bonus)
 elseif rank and bonus==nil then notes[#notes+1]='Uses base skill; bonuses unavailable.' end
 if rank and not maximum then notes[#notes+1]='Profession skill cap unavailable.' end
 if #notes>0 then result.contextNote=table.concat(notes,' ') end
 if info and rank and key=='red' and bonus==nil then result.summary='Base skill below requirement' end
 if info and rank and maximum and rank>=maximum and key~='red' then result.summary='At profession skill cap';return result end
 if info and rank and key~='unknown' then
  local nextKey=({red='orange',orange='yellow',yellow='green',green='grey'})[key]
  local nextAt=nextKey and (key=='red' and info.required or info[nextKey])
  local current=key=='red' and (effective or rank) or rank
  if nextAt and nextAt>current then
   result.nextKey=nextKey;result.nextIn=nextAt-current
   if key=='red' then result.transition=string.format(bonus~=nil and 'Gatherable at +%d skill' or 'Base requirement at +%d skill',result.nextIn)
   else result.transition=string.format('Turns %s at +%d %s',nextKey,result.nextIn,bonus and bonus~=0 and 'base skill' or 'skill') end
  end
 end
 return result
end
function R.Presentation(node,settings,mini,distance,skills,context)
 local s=R.Settings(settings);local color,label,key,source=R.Difficulty(node,skills,context)
 return {outline=mini and s.outline or 'none',icon=not mini or (s.icon and not (s.hideDistance>0 and S.Number(distance) and distance<=s.hideDistance)),
  outlineSize=s.outlineSize,iconSize=mini and s.iconSize or s.worldIconSize,iconOpacity=mini and s.miniIconOpacity or s.worldIconOpacity,outlineOpacity=s.miniOutlineOpacity,
  color=color,label=label,difficulty=key,difficultySource=source,texture=R.Icon(node)}
end
