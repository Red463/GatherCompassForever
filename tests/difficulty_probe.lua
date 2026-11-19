local function setupProbe()
 dofile('tests/wow.lua');fakeUI();local A={}
 for _,name in ipairs({'Store','Client','Resources','DifficultyProbe'}) do module(name,A) end
 A.db=A.Store.Open();A.UI={Refresh=function() end};A.Print=function(text) A.messages=A.messages or {};A.messages[#A.messages+1]=text end
 Enum={TooltipDataType={Object=4,Item=0}};local callback;local registrations=0
 TooltipDataProcessor={AddTooltipPostCall=function(kind,fn) eq(kind,4);callback=fn;registrations=registrations+1 end}
 C_Spell={GetSpellName=function(id) return id==2366 and 'Herbalism' or 'Mining' end}
 C_SkillInfo={GetSkillLineInfoByID=function(id) return {rank=id==182 and 109 or 70,modifier=5,tempPoints=0} end}
 GetBuildInfo=function() return '1.60.1','70959','date',16001 end
 GetProfessions=nil;GetProfessionInfo=nil;GetNumSkillLines=nil;GetSkillLineInfo=nil
 return A,function(...) return callback(...) end,function() return registrations end
end
local function nativeNode()
 return {type=4,guid='GameObject-0-1-1-1-1618-00001',lines={
  {leftText='Peacebloom',leftColor={r=1,g=1,b=1,a=1}},
  {leftText='Herbalism',leftColor={r=.5,g=.5,b=.5,a=1}}}}
end

test('probe captures one native gathering tooltip and records build skills and raw colours',function()
 local A,hover,registrations=setupProbe();assert(A.DifficultyProbe.Arm());eq(registrations(),1)
 hover(GameTooltip,nativeNode());eq(A.DifficultyProbe.armed,false)
 local report=A.db.difficultyProbe.latest;assert(report);eq(report.objectID,1618);eq(report.kind,'herb')
 eq(report.name,'Peacebloom');eq(report.skills.herb.rank,109);eq(report.skills.herb.modifier,5)
 eq(report.build.version,'1.60.1');eq(report.build.build,'70959');eq(report.build.interface,16001)
 near(report.lines[2].leftColor[1],.5);eq(report.classification,'Unverified native tooltip capture')
 local before=report;hover(GameTooltip,nativeNode());eq(A.db.difficultyProbe.latest,before)
 assert(A.DifficultyProbe.Arm());eq(registrations(),1);A.DifficultyProbe.Cancel();eq(A.DifficultyProbe.armed,false)
 local _,_,_,source=A.Resources.Difficulty({kind='herb',materialID='gm:herb:401'},{herb=109});eq(source,'reference')
end)

test('probe ignores own marker item tooltips unrelated objects and unreadable values',function()
 local A,hover=setupProbe();A.DifficultyProbe.Arm()
 hover(CreateFrame('Frame'),nativeNode());eq(A.db.difficultyProbe,nil)
 local data=nativeNode();data.type=0;hover(GameTooltip,data);eq(A.db.difficultyProbe,nil)
 data=nativeNode();data.lines={{leftText='Chest'}};hover(GameTooltip,data);eq(A.db.difficultyProbe,nil)
 local secret={};issecretvalue=function(v) return v==secret end
 hover(GameTooltip,secret);eq(A.db.difficultyProbe,nil)
 data=nativeNode();data.lines[2].leftColor={r=secret,g=.5,b=.5};hover(GameTooltip,data)
 local report=A.db.difficultyProbe.latest;assert(report);eq(report.lines[2].leftColor,nil)
 issecretvalue=nil
end)

test('probe bounds stored text and line count and handles failing colour methods',function()
 local A,hover=setupProbe();A.DifficultyProbe.Arm();local data=nativeNode()
 data.lines[2].leftColor={GetRGBA=function() error('unreadable colour') end}
 for i=3,100 do data.lines[i]={leftText=string.rep('x',1000)} end
 hover(GameTooltip,data);local report=A.db.difficultyProbe.latest
 eq(#report.lines,24);assert(#report.lines[3].leftText<=256);eq(report.lines[2].leftColor,nil)
 A.DifficultyProbe.Report();assert(#A.messages<=32)
end)

test('probe missing tooltip API reports unavailable without touching saved data',function()
 local A=setupProbe();TooltipDataProcessor=nil
 local ok=A.DifficultyProbe.Arm();eq(ok,nil);eq(A.DifficultyProbe.armed,false);eq(A.db.difficultyProbe,nil)
 assert(A.messages[#A.messages]:find('unavailable',1,true))
 A.DifficultyProbe.Report();assert(A.messages[#A.messages]:find('No node report',1,true))
 C_SkillInfo=nil;GetBuildInfo=nil;Enum=nil
end)


test('probe cancellation ignores later tooltips and rearming captures localized numeric-id nodes',function()
 local A,hover,registrations=setupProbe();A.DifficultyProbe.Arm();A.DifficultyProbe.Cancel()
 hover(GameTooltip,nativeNode());eq(A.db.difficultyProbe,nil)
 C_Spell.GetSpellName=function(id) return id==2366 and 'Herboristerie' or 'Minage' end
 C_SkillInfo.GetSkillLineInfoByID=function() error('not readable') end
 GetBuildInfo=function() error('not available') end
 A.DifficultyProbe.Arm();eq(registrations(),1)
 hover(GameTooltip,{type=4,id=656160,lines={{leftText='Herbe inconnue'},{rightText='Herboristerie',rightColor={r=.25,g=.75,b=.25,a=1}}}})
 local report=A.db.difficultyProbe.latest;eq(report.objectID,656160);eq(report.kind,'herb')
 eq(report.skills.herb.rank,nil);eq(report.build.version,nil);near(report.lines[2].rightColor[2],.75)
 A.DifficultyProbe.Report();eq(A.DifficultyProbe.armed,false)
 C_SkillInfo=nil;GetBuildInfo=nil;Enum=nil
end)
