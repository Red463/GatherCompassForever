test('structured tooltips colour chance and threshold lines while escaping names',function()
 dofile('tests/wow.lua');fakeUI();local A={};module('Store',A);module('Resources',A);module('SkillTooltip',A)
 A.Resources.Skills=function() return {herb=109},{herb={maxRank=150,bonus=0}} end
 local lines={};GameTooltip.SetText=function(_,text) lines={{text=text}} end
 GameTooltip.AddLine=function(_,text,r,g,b) lines[#lines+1]={text=text,r=r,g=g,b=b} end
 A.SkillTooltip.Show(UIParent,'Material',{{node={kind='herb',materialID='gm:herb:403',name='|cff00ff00Earthroot'}}})
 local chance,nextLine
 for _,l in ipairs(lines) do if l.text=='Sometimes a skill-up' then chance=l elseif l.text:find('Turns grey',1,true) then nextLine=l end end
 assert(chance and nextLine);near(chance.g,A.Resources.colors.green[2]);near(nextLine.r,A.Resources.colors.grey[1]);assert(lines[2].text:find('||cff',1,true))
end)
