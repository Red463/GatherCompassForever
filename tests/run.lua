local passed, failed = 0, 0
function test(name, fn)
 local ok, err = pcall(fn)
 if ok then passed=passed+1 else failed=failed+1; print('FAIL '..name..': '..tostring(err)) end
end
function eq(a,b) assert(a==b, tostring(a)..' ~= '..tostring(b)) end
function near(a,b) assert(math.abs(a-b)<0.00001, tostring(a)..' not near '..tostring(b)) end
function module(name,A)
 if name=='Planner' and not A.Corridor then module('Corridor',A) end
 if name=='Map' and not A.Heatmap then module('Heatmap',A) end
 if name=='Map' and not A.Resources then module('Resources',A) end
 if name=='Map' and not A.Selection then module('Selection',A) end
 local f=loadfile(name..'.lua'); assert(f, 'Missing module '..name); f('GatherCompassForever',A)
end
function moduleUI(A)
 if not A.FarmingSession then module('FarmingSession',A) end
 for _,name in ipairs({'Resources','MarkerGroups','SkillTooltip','Selection','Atlas','ResourceLibrary','Skin','Dropdown','Heatmap','MapArt','RouteSketch','RouteView','ResourceLibraryView','UIActions','FilterSidebar','WelcomeView','UI'}) do module(name,A) end
end
function distance(a,b)
 if not a or not b or a.mapID~=b.mapID then return nil end
 return math.sqrt(((a.x-b.x)*1000)^2+((a.y-b.y)*500)^2)
end
function point(x,y) return {mapID=1,x=x,y=y or 0.5,kind='travel'} end
local suites={'store','resources','selection','marker_groups','skill_tooltip','atlas','resource_library','codex','client','gathering','imports','editor','recorder','planner','farming_session','map_art','heatmap','follower','map','skin','dropdown','arrow','minimap_button','difficulty_probe','filter_sidebar','welcome','route_view','ui','resource_library_view','expedition','bootstrap'}
for _,suite in ipairs(suites) do
 local f=io.open('tests/'..suite..'.lua')
 assert(f,'Missing required test suite: '..suite); f:close(); dofile('tests/'..suite..'.lua')
end
print(string.format('RESULT %d passed, %d failed',passed,failed))
assert(failed==0,'test failures')
