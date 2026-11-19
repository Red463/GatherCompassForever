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

test('group hover is compact skill-coloured names with right aligned counts',function()
 dofile('tests/wow.lua');fakeUI();local A={};for _,m in ipairs({'Store','Resources','MarkerGroups','SkillTooltip'}) do module(m,A) end
 A.Resources.Skills=function() return {herb=109},{herb={maxRank=150,bonus=0}} end
 local title,rows,lines;rows={};lines={}
 GameTooltip.SetText=function(_,s) title=s end
 GameTooltip.AddLine=function(_,s) lines[#lines+1]=s end
 GameTooltip.AddDoubleLine=function(_,name,count,r,g,b) rows[#rows+1]={name=name,count=count,color={r,g,b}} end
 local nodes={{key='a',kind='herb',materialID='gm:herb:403',name='Earthroot'},{key='b',kind='herb',materialID='gm:herb:403',name='Earthroot'},
  {key='c',kind='herb',materialID='unknown',name='Unusual |cffff0000herb'}}
 A.SkillTooltip.ShowGroup(UIParent,{members=nodes})
 eq(title,'3 nodes here');eq(#rows,2);eq(rows[1].name,'Earthroot');eq(rows[1].count,'x2');near(rows[1].color[2],A.Resources.colors.green[2])
 eq(rows[2].name,'Unusual ||cffff0000herb');eq(#lines,1);eq(lines[1],'Zoom in to see each one.')
end)
