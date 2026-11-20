local function resources()
 local A={}; module('Store',A); module('Client',A); module('Resources',A); return A
end
local herb={kind='herb',materialID='gm:herb:401',name='Peacebloom'}
test('minimap heat colour defaults validate independently and persist across saved-data reload',function()
 local A=resources();local db=A.Store.Open();local s=A.Resources.Settings(db.settings)
 eq(s.miniHeatColour,'amber');s.miniHeatColour='cyan';s.miniHeatOpacity=.35;s.worldHeatOpacity=.25
 s=A.Resources.Settings(A.Store.Open(A.Store.Copy(db)).settings);eq(s.miniHeatColour,'cyan');eq(s.miniHeatOpacity,.35);eq(s.worldHeatOpacity,.25)
 for _,bad in ipairs({'purple',42,{}}) do s.miniHeatColour=bad;eq(A.Resources.Settings({nodeDisplay=s}).miniHeatColour,'amber') end
end)
test('node opacity defaults validate independently and survive saved-data reload',function()
 local A=resources();local settings={};local s=A.Resources.Settings(settings)
 eq(s.worldIconOpacity,1);eq(s.miniIconOpacity,1);eq(s.miniOutlineOpacity,1)
 s.worldIconOpacity=.25;s.miniIconOpacity=.5;s.miniOutlineOpacity=.75
 local world=A.Resources.Presentation(herb,settings,false,100,{herb=10})
 local mini=A.Resources.Presentation(herb,settings,true,100,{herb=10})
 eq(world.iconOpacity,.25);eq(mini.iconOpacity,.5);eq(mini.outlineOpacity,.75)
 local saved=A.Store.Open();saved.settings=settings;s=A.Resources.Settings(A.Store.Open(A.Store.Copy(saved)).settings)
 eq(s.worldIconOpacity,.25);eq(s.miniIconOpacity,.5);eq(s.miniOutlineOpacity,.75)
 s.worldIconOpacity=-1;s.miniIconOpacity=2;s.miniOutlineOpacity=0/0;s=A.Resources.Settings({nodeDisplay=s})
 eq(s.worldIconOpacity,0);eq(s.miniIconOpacity,1);eq(s.miniOutlineOpacity,1)
end)
test('world heat defaults to half opacity while other overlays retain their defaults',function()
 local R=resources().Resources
 local fresh=R.Settings({})
 eq(fresh.worldLineOpacity,1);eq(fresh.worldHeatOpacity,.5)
 eq(fresh.miniLineOpacity,.65);eq(fresh.miniHeatOpacity,.65)
 for _,legacy in ipairs({.35,0}) do
  local s=R.Settings({nodeDisplay={routeOpacity=legacy}})
  eq(s.worldLineOpacity,1);eq(s.worldHeatOpacity,.5)
  eq(s.miniLineOpacity,legacy);eq(s.miniHeatOpacity,legacy);eq(s.routeOpacity,legacy)
 end
end)
test('persisted style opacities survive reload and take priority over legacy opacity',function()
 local A=resources();local saved=A.Store.Open()
 saved.settings.nodeDisplay={routeOpacity=.35,worldLineOpacity=0,worldHeatOpacity=.75,miniLineOpacity=0}
 local s=A.Resources.Settings(saved.settings)
 eq(s.worldLineOpacity,0);eq(s.worldHeatOpacity,.75);eq(s.miniLineOpacity,0);eq(s.miniHeatOpacity,.35)
 s.routeOpacity=.85
 s=A.Resources.Settings(A.Store.Open(A.Store.Copy(saved)).settings)
 eq(s.worldLineOpacity,0);eq(s.worldHeatOpacity,.75);eq(s.miniLineOpacity,0);eq(s.miniHeatOpacity,.35)
 eq(s.routeOpacity,.85)
end)
test('each route opacity clamps finite values and replaces malformed values',function()
 local R=resources().Resources
 local s=R.Settings({nodeDisplay={routeOpacity=.35,worldLineOpacity=-1,worldHeatOpacity=math.huge,miniLineOpacity=2,miniHeatOpacity=0/0}})
 eq(s.worldLineOpacity,0);eq(s.worldHeatOpacity,.5);eq(s.miniLineOpacity,1);eq(s.miniHeatOpacity,.65)
 s=R.Settings({nodeDisplay={routeOpacity='0'}})
 eq(s.miniLineOpacity,.65);eq(s.miniHeatOpacity,.65)
end)
test('starter resources follow minimum-relative boundaries and never guess unknown resources',function()
 local A=resources(); local R=A.Resources
 for _,node in ipairs({herb,{kind='herb',materialID='gm:herb:402'},{kind='ore',materialID='gm:ore:201'}}) do
  for _,case in ipairs({{0,'red'},{1,'orange'},{25,'orange'},{26,'yellow'},{50,'yellow'},{51,'green'},{100,'green'},{101,'grey'}}) do
   local _,label,key=R.Difficulty(node,{[node.kind]=case[1]});eq(key,case[2]);assert(label:find('Reference data',1,true))
  end
 end
 local _,_,key=R.Difficulty({kind='ore',materialID='gm:ore:202'},{ore=64}); eq(key,'red')
 _,_,key=R.Difficulty(herb,{}); eq(key,'unknown')
 _,_,key=R.Difficulty({kind='herb',name='Unknown custom herb',materialID='gm:herb:99999'},{herb=300}); eq(key,'unknown')
end)
test('marker defaults validate saved settings and hide only a nearby minimap icon',function()
 local R=resources().Resources; local settings={}; local s=R.Settings(settings)
 eq(s.outline,'ring'); eq(s.icon,true); eq(s.outlineSize,24); eq(s.iconSize,14); eq(s.hideDistance,20)
 local p=R.Presentation(herb,settings,true,20,{herb=10}); eq(p.icon,false); eq(p.outline,'ring')
 eq(R.Presentation(herb,settings,true,21,{}).icon,true)
 eq(R.Presentation(herb,settings,true,nil,{}).icon,true)
 eq(R.Presentation(herb,settings,false,1,{}).icon,true)
 s.hideDistance=0; eq(R.Presentation(herb,settings,true,1,{}).icon,true)
 s.outline='none';s.icon=false;s.iconSize=0/0;s.outlineSize=100000;s.hideDistance=-1
 s=R.Settings(settings); eq(s.icon,true);eq(s.iconSize,14);eq(s.outlineSize,32);eq(s.hideDistance,0)
 s.iconSize=2;s.worldIconSize=7.6;s.outlineSize=9.2
 s=R.Settings(settings);eq(s.iconSize,4);eq(s.worldIconSize,8);eq(s.outlineSize,9)
end)
test('profession reads use stable IDs handle missing APIs and do not retain other characters ranks',function()
 local R=resources().Resources
 GetProfessions=function() return 1,2 end
 GetProfessionInfo=function(i) return 'Localized profession',nil,i==1 and 80 or 140,300,0,0,i==1 and 182 or 186 end
 local ranks=R.Skills();eq(ranks.herb,80);eq(ranks.ore,140)
 GetProfessions=nil;GetProfessionInfo=nil;GetNumSkillLines=nil;GetSkillLineInfo=nil
 ranks=R.Skills();eq(ranks.herb,nil);eq(ranks.ore,nil)
 GetNumSkillLines=function() return 2 end
 GetSkillLineInfo=function(i) return i==1 and 'Herbalism' or 'Mining',false,false,i==1 and 12 or 64,0,0,150 end
 ranks=R.Skills();eq(ranks.herb,12);eq(ranks.ore,64)
 GetNumSkillLines=nil;GetSkillLineInfo=nil
end)
test('resource icons prefer installed references and always have a standalone fallback',function()
 local R=resources().Resources
 GatherMate2={nodeTextures={['Herb Gathering']={[401]='custom-texture'}}}
 eq(R.Icon(herb),'custom-texture');GatherMate2=nil
 C_Item={GetItemIconByID=function(id) if id==2447 then return 12345 end end}
 eq(R.Icon(herb),12345);C_Item=nil
 assert(type(R.Icon(herb))=='string');assert(type(R.Icon({kind='ore'}))=='string')
end)


test('world-map nodes always use icons independently of minimap outline and icon switches',function()
 local R=resources().Resources;local settings={};local s=R.Settings(settings)
 for _,outline in ipairs({'ring','square','none'}) do
  s.outline=outline;s.icon=false
  local world=R.Presentation(herb,settings,false,0,{herb=10})
  eq(world.outline,'none');eq(world.icon,true)
  local mini=R.Presentation(herb,settings,true,0,{herb=10})
  eq(mini.outline,outline)
 end
end)


test('difficulty reports explicit source without implying native verification',function()
 local R=resources().Resources
 local _,label,key,source=R.Difficulty(herb,{herb=26})
 eq(key,'yellow');eq(source,'reference');assert(label:find('Mastercraft',1,true))
 local _,unknown,_,unknownSource=R.Difficulty({kind='herb',name='Custom node'},{});eq(unknownSource,'unknown')
 assert(unknown:find('Unknown',1,true));assert(not label:lower():find('estimat',1,true))
end)


test('skill details describe the current tier and distance to its next colour',function()
 local R=resources().Resources;assert(type(R.SkillDetails)=='function')
 local earthroot={kind='herb',materialID='gm:herb:403',name='Earthroot'}
 local details=R.SkillDetails(earthroot,{herb=109})
 eq(details.key,'green');eq(details.required,15);eq(details.rank,109)
 eq(details.requirement,'Requires 15 (you have 109)');eq(details.summary,'Sometimes a skill-up')
 eq(details.nextIn,6);eq(details.nextKey,'grey');eq(details.transition,'Turns grey at +6 skill');eq(details.source,'reference')
 for _,case in ipairs({{14,'red',1},{15,'orange',25},{40,'yellow',25},{65,'green',50},{115,'grey'}}) do
  local d=R.SkillDetails(earthroot,{herb=case[1]});eq(d.key,case[2]);eq(d.nextIn,case[3])
 end
 local locked=R.SkillDetails(earthroot,{herb=14},{herb={maxRank=300,bonus=0}});eq(locked.transition,'Gatherable at +1 skill')
 local orange=R.SkillDetails(earthroot,{herb=15});eq(orange.summary,'Always a skill-up')
end)

test('starter skill guidance changes tier and remaining distance together',function()
 local R=resources().Resources
 for _,case in ipairs({{25,'orange',1,'yellow'},{26,'yellow',25,'green'},{50,'yellow',1,'green'},{51,'green',50,'grey'},{100,'green',1,'grey'},{101,'grey'}}) do
  local d=R.SkillDetails(herb,{herb=case[1]},{herb={maxRank=150,bonus=0}})
  eq(d.key,case[2]);eq(d.nextIn,case[3]);eq(d.nextKey,case[4])
 end
end)

test('skill details keep missing thresholds and unreadable ranks unknown without invented transitions',function()
 local R=resources().Resources;assert(type(R.SkillDetails)=='function')
 local missing=R.SkillDetails({kind='herb',name='Custom unknown resource'},{herb=109})
 eq(missing.key,'unknown');eq(missing.source,'unknown');eq(missing.nextIn,nil)
 eq(missing.summary,'Skill-up chance unknown');assert(missing.requirement:find('Required skill unknown',1,true))
 local unreadable=R.SkillDetails({kind='herb',materialID='gm:herb:403'},{});eq(unreadable.required,15)
 eq(unreadable.key,'unknown');eq(unreadable.transition,nil);eq(unreadable.requirement,'Requires 15 (skill unavailable)')
end)


test('skill guidance accounts for profession caps and effective gathering bonuses',function()
 local R=resources().Resources;local earthroot={kind='herb',materialID='gm:herb:403'}
 local capped=R.SkillDetails(earthroot,{herb=75},{herb={maxRank=75,bonus=0}})
 eq(capped.key,'grey');eq(capped.summary,'At profession skill cap');eq(capped.transition,nil)
 local steel={kind='herb',materialID='gm:herb:409'}
 local boosted=R.SkillDetails(steel,{herb=110},{herb={maxRank=150,bonus=5}})
 eq(boosted.key,'orange');eq(boosted.effectiveSkill,115);eq(boosted.requirement,'Requires 115 (you have 115)')
 assert(boosted.contextNote:find('Base skill 110',1,true));assert(boosted.transition:find('base skill',1,true))
 local unknown=R.SkillDetails(steel,{herb=110});eq(unknown.summary,'Base skill below requirement')
 assert(unknown.contextNote:find('unavailable',1,true))
end)

test('profession context reads native caps and bonuses and preserves the legacy fallback',function()
 local R=resources().Resources
 C_SkillInfo={GetSkillLineInfoByID=function(id) if id==182 then return {rank=110,maxRank=150,modifier=3,tempPoints=2} end end}
 local ranks,context=R.Skills();eq(ranks.herb,110);eq(context.herb.maxRank,150);eq(context.herb.bonus,5)
 C_SkillInfo=nil;GetProfessions=function() return 1 end
 GetProfessionInfo=function() return 'Herbalism',nil,109,150,0,0,182,5 end
 ranks,context=R.Skills();eq(ranks.herb,109);eq(context.herb.maxRank,150);eq(context.herb.bonus,5)
 GetProfessions=nil;GetProfessionInfo=nil
end)
