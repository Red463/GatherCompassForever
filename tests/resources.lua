local function resources()
 local A={}; module('Store',A); module('Client',A); module('Resources',A); return A
end
local herb={kind='herb',materialID='gm:herb:401',name='Peacebloom'}
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
test('Classic difficulty colours use boundaries and never guess unknown resources',function()
 local A=resources(); local R=A.Resources
 for _,case in ipairs({{1,'orange'},{24,'orange'},{25,'yellow'},{49,'yellow'},{50,'green'},{99,'green'},{100,'grey'}}) do
  local _,label,key=R.Difficulty(herb,{herb=case[1]}); eq(key,case[2]); assert(label:find('Reference data',1,true))
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
 s=R.Settings(settings); eq(s.icon,true);eq(s.iconSize,14);eq(s.outlineSize,40);eq(s.hideDistance,0)
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
 local _,label,key,source=R.Difficulty(herb,{herb=25})
 eq(key,'yellow');eq(source,'reference');assert(label:find('Classic',1,true))
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
 local orange=R.SkillDetails(earthroot,{herb=15});eq(orange.summary,'High skill-up chance')
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
