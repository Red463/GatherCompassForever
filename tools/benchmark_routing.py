"""Benchmark the real planning job at simulated FPS, with no game writes.

Accepts the preserved Ashenvale report or a JSON list of nodes. CPU timings are
local harness measurements; simulated time includes cooperative frame yields.
"""
from pathlib import Path
import argparse,json,os,subprocess,sys,time
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'.test-deps'))
from lupa.lua51 import LuaRuntime

def main():
 p=argparse.ArgumentParser(description=__doc__)
 p.add_argument('--nodes',type=Path,default=ROOT.parent/'output/ashenvale-route-preview/route-report.json')
 p.add_argument('--map',type=int,default=1440);p.add_argument('--start',help='Normalized x,y')
 p.add_argument('--limit',type=int);p.add_argument('--coverage',type=float,default=180)
 p.add_argument('--fps',type=float,default=60);p.add_argument('--repeat',type=int,default=2)
 p.add_argument('--move-yards',type=float,default=0,help='Move the example start east between repeat runs')
 p.add_argument('--revision',help='Read modules from a Git revision for comparison')
 p.add_argument('--output',type=Path)
 args=p.parse_args();os.chdir(ROOT)
 if args.fps<=0 or args.repeat<1:p.error('FPS and repeat count must be positive')
 raw=json.loads(args.nodes.read_text(encoding='utf-8'))
 nodes=raw['nodes'] if isinstance(raw,dict) else raw
 if args.limit:nodes=nodes[:args.limit]
 start=dict(zip(('x','y'),map(float,args.start.split(',')))) if args.start else raw.get('example_start',{'x':.4,'y':.55}) if isinstance(raw,dict) else {'x':.3,'y':.5}
 lua=LuaRuntime(unpack_returned_tuples=True);lua.globals().millis=lambda:time.perf_counter()*1000
 lua.execute('A={};frameClock=0;debugprofilestop=function() return millis() end;GetTime=function() return frameClock end')
 for name in ('Store','Data/Terrain','Terrain','Coverage','Corridor','Planner','FarmingSession','Follower','PlanningJob'):
  source=subprocess.check_output(['git','show',args.revision+':'+name+'.lua'],cwd=ROOT).decode() if args.revision and name!='Data/Terrain' else (ROOT/(name+'.lua')).read_text(encoding='utf-8')
  lua.execute('assert(loadstring(...))("Gatherly",A)',source)
 converted=[]
 for i,n in enumerate(nodes):
  kind=n.get('kind');material=n.get('materialID') or 'gm:herb:'+str(kind if isinstance(kind,int) else 'unknown')
  converted.append(dict(mapID=args.map,x=n['x'],y=n['y'],kind=kind if kind in ('herb','ore') else 'herb',materialID=material,name=n.get('name','Herb'),key=n.get('key','n'+str(i))))
 lua.globals().nodes=lua.table_from(converted,recursive=True)
 lua.globals().start=lua.table_from(dict(mapID=args.map,**start));lua.globals().coverage=args.coverage
 lua.execute('''
local zone=assert(A.Terrain.Zone(start.mapID));start=assert(A.Terrain.Approach(start,100))
local function distance(a,b) if not a or not b or a.mapID~=b.mapID then return end;return math.sqrt(((a.x-b.x)*zone.widthYards)^2+((a.y-b.y)*zone.heightYards)^2) end
A.Client={Position=function() return start end,Distance=distance};A.db=A.Store.Open()
metrics={}
local function profile(owner,key,label)
 local fn=owner[key]
 owner[key]=function(...)
  metrics[label..'Calls']=(metrics[label..'Calls'] or 0)+1
  local before=millis();local a,b,c=fn(...);metrics[label..'Milliseconds']=(metrics[label..'Milliseconds'] or 0)+millis()-before
  return a,b,c
 end
end
profile(A.Terrain,'Path','path');profile(A.Terrain,'Route','expand');profile(A.Coverage,'TerrainPlan','coverage');profile(A.Follower,'New','follower')
function begin()
 metrics={};finished=false;result=nil;failure=nil
 A.PlanJob(function()
  local plan,reason=A.FarmingSession.New(nodes,start,distance,{coverageRadius=coverage,viewRadius=coverage/.9,name='Benchmark route'})
  if not plan then return nil,reason end
  local follower=A.Follower.New(plan.route,start,distance,{arrival=15})
  assert(follower.status=='running',follower.reason)
  return plan.route
 end,function(route,reason) result=route;failure=reason;finished=true end,function(reason) failure=reason;finished=true end)
end
''')
 reports=[]
 for run in range(args.repeat):
  if run and args.move_yards:
   lua.globals().moveYards=args.move_yards
   lua.execute('local z=A.Terrain.Zone(start.mapID);start=assert(A.Terrain.Approach({mapID=start.mapID,x=math.min(1,math.max(0,start.x+moveYards/z.widthYards)),y=start.y},100))')
  lua.globals().begin();ticks=[];frames=0;memory_peak=0
  while not lua.globals().finished and frames<30000:
   frames+=1;lua.globals().frameClock=frames/args.fps
   before=time.perf_counter();lua.globals().A.PlanningJob.Tick();ticks.append((time.perf_counter()-before)*1000)
   memory_peak=max(memory_peak,lua.eval('collectgarbage("count")'))
  route=lua.globals().result
  assert route is not None,lua.globals().failure or 'Timed out'
  lua.execute('assert(A.Terrain.Validate(result))')
  stats=dict(lua.globals().metrics)
  report=dict(run=run+1,selected=len(nodes),included=route['includedCount'],navigationPoints=len(route['points']),
   frames=frames,simulatedSeconds=round(frames/args.fps,3),processingMilliseconds=round(sum(ticks),2),
   p95FrameMilliseconds=round(sorted(ticks)[int((len(ticks)-1)*.95)],3),maxFrameMilliseconds=round(max(ticks),3),
   memoryPeakKiB=round(memory_peak),metrics={k:round(v,2) for k,v in stats.items()})
  reports.append(report);print(json.dumps(report),flush=True)
 if args.output:args.output.write_text(json.dumps(reports,indent=2)+'\n',encoding='utf-8')

if __name__=='__main__':main()
