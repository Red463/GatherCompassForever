local _, A = ...
local D={armed=false};A.DifficultyProbe=D
local S=A.Store
local function read(value) return A.Client.Read(value) end
local function call(fn,...)
 if type(fn)~='function' then return end
 local ok,a,b,c,d=pcall(fn,...);if ok then return read(a),read(b),read(c),read(d) end
end
local function text(value)
 value=read(value);if type(value)~='string' then return end
 return value:gsub('|c%x%x%x%x%x%x%x%x',''):gsub('|r',''):gsub('[%c]',' '):sub(1,256)
end
local function number(value) value=read(value);if S.Number(value) then return value end end
local function color(value)
 local ok,result=pcall(function()
  value=read(value);if type(value)~='table' and type(value)~='userdata' then return end
  local r,g,b,a
  if type(value.GetRGBA)=='function' then r,g,b,a=call(value.GetRGBA,value)
  else r,g,b,a=read(value.r),read(value.g),read(value.b),read(value.a) end
  if not S.Number(r) or not S.Number(g) or not S.Number(b) then return end
  if r<0 or r>1 or g<0 or g>1 or b<0 or b>1 then return end
  return {r,g,b,S.Number(a) and a or 1}
 end)
 return ok and result or nil
end
local function context()
 local ranks=A.Resources.Skills();local skills={}
 for kind,id in pairs({herb=182,ore=186}) do
  local info=call(C_SkillInfo and C_SkillInfo.GetSkillLineInfoByID,id)
  if type(info)=='table' and number(info.rank) then
   skills[kind]={rank=number(info.rank),modifier=number(info.modifier),tempPoints=number(info.tempPoints),source='C_SkillInfo'}
  else skills[kind]={rank=number(ranks[kind]),source='Profession rank; modifiers unavailable'} end
 end
 local version,build,_,interface=call(GetBuildInfo)
 return skills,{version=text(version),build=text(build),interface=number(interface)}
end
local function capture(data)
 data=read(data);if type(data)~='table' or read(data.type)~=D.objectType then return end
 local lines=read(data.lines);if type(lines)~='table' then return end
 local guid=text(data.guid);local objectID=guid and tonumber(guid:match('^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)%-')) or nil
 if guid and not objectID then return end
 objectID=objectID or number(data.id);if not objectID then return end
 local collected={}
 for i=1,24 do
  local line=read(lines[i]);if line==nil then break end
  if type(line)=='table' then collected[#collected+1]={leftText=text(line.leftText),rightText=text(line.rightText),leftColor=color(line.leftColor),rightColor=color(line.rightColor),type=number(line.type)} end
 end
 local name=collected[1] and collected[1].leftText;if not name then return end
 local kind
 for _,candidate in ipairs({'herb','ore'}) do
  local known=A.Resources.Info({kind=candidate,name=name})
  local label=text(call(C_Spell and C_Spell.GetSpellName or GetSpellInfo,candidate=='herb' and 2366 or 2575)) or (candidate=='herb' and 'Herbalism' or 'Mining')
  local matches=known~=nil
  for _,line in ipairs(collected) do
   if line.leftText and line.leftText:find(label,1,true) or line.rightText and line.rightText:find(label,1,true) then matches=true end
  end
  if matches then if kind then return end;kind=candidate end
 end
 if not kind then return end
 local skills,build=context()
 return {version=1,name=name,kind=kind,guid=guid,objectID=objectID,lines=collected,skills=skills,build=build,capturedAt=number(call(time)),classification='Unverified native tooltip capture'}
end
function D.Capture(data)
 local ok,report=pcall(capture,data);if ok then return report end
end
local function message(value)
 value=tostring(value):gsub('|','||')
 if A.Print then A.Print(value) end
end
local function status(value) A.status=value;message(value);if A.UI then A.UI.Refresh() end end
function D.OnTooltip(tooltip,data)
 if not D.armed or tooltip~=GameTooltip then return end
 local report=D.Capture(data);if not report or not A.db then return end
 D.armed=false
 local saved=type(A.db.difficultyProbe)=='table' and A.db.difficultyProbe or {};A.db.difficultyProbe=saved;saved.latest=report
 status('Node report captured: '..report.name..'. Use /gatherly inspect report to view it. Colours still use reference data until the native fields are validated.')
end
function D.Arm()
 if not D.registered then
  local object=Enum and Enum.TooltipDataType and Enum.TooltipDataType.Object
  local api=TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
  if type(api)~='function' or not S.Number(object) then
   D.armed=false;status('Native node inspection is unavailable on this client. Reference colours remain available.');return nil
  end
  local ok=pcall(api,object,D.OnTooltip)
  if not ok then D.armed=false;status('Native node inspection is unavailable on this client. Reference colours remain available.');return nil end
  D.objectType=object;D.registered=true
 end
 D.armed=true;status('Node inspection ready. Hover an actual herb or vein in the game world; map markers do not qualify. /gatherly inspect off cancels.');return true
end
function D.Cancel() D.armed=false;status('Node inspection cancelled.') end
function D.Report()
 local report=A.db and type(A.db.difficultyProbe)=='table' and A.db.difficultyProbe.latest
 if type(report)~='table' or report.version~=1 or type(report.lines)~='table' then message('No node report saved. Use /gatherly inspect, then hover an actual herb or vein.');return end
 local function show(value) return text(value) or (S.Number(value) and tostring(value)) or '?' end
 local build=type(report.build)=='table' and report.build or {}
 message('Native node report: '..show(report.name)..' (object '..show(report.objectID)..'; '..show(report.kind)..').')
 message('Client: '..show(build.version)..' build '..show(build.build)..' / interface '..show(build.interface)..'. Unverified native tooltip capture.')
 for _,kind in ipairs({'herb','ore'}) do
  local skill=type(report.skills)=='table' and report.skills[kind];skill=type(skill)=='table' and skill or {}
  message(kind..': rank '..show(skill.rank)..', modifier '..show(skill.modifier)..', temporary '..show(skill.tempPoints)..'.')
 end
 local function rgb(value)
  if type(value)~='table' or not S.Number(value[1]) or not S.Number(value[2]) or not S.Number(value[3]) then return '[colour unavailable]' end
  return string.format('[%.3f, %.3f, %.3f]',value[1],value[2],value[3])
 end
 for i=1,math.min(#report.lines,24) do
  local line=report.lines[i]
  if type(line)=='table' then message('Line '..i..': '..show(line.leftText)..' '..rgb(line.leftColor)..' / '..show(line.rightText)..' '..rgb(line.rightColor)) end
 end
end
