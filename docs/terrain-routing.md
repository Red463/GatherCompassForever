# Supplied terrain routing

The addon ships compact masks in `Data/Terrain.lua`, generated from the separate
read-only snapshot of Forever 1.60.1 build 70959. Runtime routing is entirely Lua
inside Gatherly. It requires no external program, extraction, map drawing or
file access in the client. The generator and CASC reader are our own Python tools,
run during development outside the game.

## Coverage

All 55 local maps exposed by this build's UI-map metadata have masks: outdoor
zones, cities, battlegrounds, Mount Hyjal, Zephras Isle, Darkspear Islands,
Riverglades and Shen'dralas. Forty-three have complete indexed terrain.
Twelve have unavailable sections: Durotar, The Barrens, Stranglethorn Vale,
Teldrassil, Desolace, Feralas, Dustwallow Marsh, Tanaris, Winterspring, Alterac
Valley and both Zephras Isle map IDs. Unavailable cells remain prohibited.
The five world/continent overview records explicitly reject routing; use their
local zone maps. This is not an interior-dungeon navigation dataset.

“Complete” means all cells have indexed terrain, not that collision geometry has
been checked. Data is tied to build 70959 and must be regenerated when terrain
or zone bounds change.

## Mask rules

1. Sample each terrain cell, approximately 4.17 yards across, using all four
   triangles around its centre height. Restrict cells whose steepest triangle
   reaches 50 degrees, and terrain holes.
2. Permit liquid cells, including swimming routes. Liquid overrides terrain
   slope restrictions and remains separate until cleanup is complete.
3. Remove complete eight-connected restricted components of only one or two
   cells, except components touching map edges, liquid or unknown data.
   This tolerates isolated small obstacles; it is not a physical jump simulation.
4. Fill enclosed candidate components other than the largest. Preserve components
   touching map edges, liquid or unknown data.
5. Encode candidate and liquid cells as permitted; restrictions and missing
   terrain remain prohibited. Ashenvale reproduces the approved mask byte-for-byte.

Review PNGs use white for candidates, black for restrictions, mid-grey for
permitted liquid and dark grey for unavailable terrain. Runtime packed rows use
six cells per standard 64-character-alphabet character, first cell in the high bit.

## Route rules

Every navigation segment must pass a conservative cell-intersection check,
including cells touched at grid corners. Eight-neighbour A* cannot cut diagonally
between restrictions. Smoothing accepts only shortcuts passing the same check.
Travel bends are mandatory and do not count as gathering stops.

A node slightly inside a restriction may use a permitted approach within 30
yards. It never becomes a tunnel through the restriction. This distance is a
routing tolerance, not a confirmed gathering range; players may need to approach
the actual spawn manually. Coverage checks the original spawn's distance from
the corridor and a permitted connector to its approach.

Planning retains the local-corridor workflow: at most 40 nearby farming areas,
connections of at most 450 yards measured along permitted paths, and a verified
closing connection. Included and omitted counts remain visible. Selecting all
materials does not promise a circuit covering the whole zone. Backtracking has no
added penalty; necessary branch returns remain.

Generation, saved-route starts, resource guidance, removal/undo and explicit
resume use a cooperative planning job. The soft frame budget is four milliseconds,
with a work cap for frozen timers. This is not a hard real-time guarantee.
Cheap checkpoints no longer force an early yield while the profiling clock is
advancing. Decoded mask rows are reused within a four-MiB cache. Local path results
and completely searched unreachable pairs are retained within 1,024 entries and
8,192 path vertices for the current zone; search-budget failures are not retained.
Changes to mask rows or map dimensions invalidate those results. These caches are
in memory and do not change the supplied overlays. A fresh zone or reload still
requires searches; repeating a nearby plan can reuse much of that work.
Automatic recovery uses a smaller search budget and can suspend until the player
moves nearer or chooses Resume. Missing data, unreachable paths and exhausted
budgets produce explanations when searching for permitted connections.

The masks constrain planned paths, not the player's actual movement. A readable
player position in a blocked cell does not suspend guidance or trigger a new
join. The follower keeps its current waypoint/connector, direction and lap;
arrival and Skip remain available. Pause/Resume and position recovery also work
from blocked cells. When starting there, the nearest planned waypoint is selected
by direct distance. No blocked endpoint is passed to the terrain pathfinder.
Once back on permitted terrain, normal connector and corner checks apply again.
Resource stops advance within the selected arrival radius after gathering ends
and the overlapping-stop movement guard is satisfied. A blocked direct line to
the following leg does not delay that resource step: the follower can build a
permitted connector after advancing. Travel bends still require a clear following
segment before they can be passed early, so they may need a closer approach than
the selected radius.
Unavailable coordinates, another zone and overly long connections can still
suspend guidance.

The initial join selects a nearby route entry and direction. Recovery and Resume
keep that established direction, current leg and lap accounting; they reconnect
to the current target rather than selecting an earlier nearby waypoint. A failed
or overly long connection suspends guidance until the player moves nearer.
The Reverse control still changes direction deliberately, and planned branch
returns remain part of the route.

The follower checks connectors after skipping, reversing, arrival and movement.
Old saved paths are expanded into a terrain-safe copy before use; saved data is
not rewritten. Both line views retain terrain bends. Heat is visual paint around
the path: soft edges can overlap restricted cells, while the centreline follows
the mask. Sampling becomes coarser across the whole path rather than losing its tail.

## Limits and verification

These are terrain heuristics, not a collision/navmesh extraction. Trees, fences,
buildings, caves, bridges, elevators, one-way drops and layered interiors are not
represented. A permitted two-dimensional cell cannot distinguish levels. Liquid
permission does not evaluate hazards. The 50-degree threshold has not been proven
to match the client's movement limit. In-client checks remain necessary,
especially in cities and custom areas.

`python tests/run_tests.py` checks all packed maps, generator rules, intersections,
mandatory bends, coverage, guidance transitions, transactional edits, queued jobs
and the production module order. `tools/verify_terrain_routes.py` runs supplied node
JSON through the actual Lua planner and independently intersects every route
segment against blocked grid rectangles, without relying on Lua's segment checker.

`python tools/benchmark_routing.py --nodes path/to/node-report.json` benchmarks the
actual planning job, session and initial follower join. It reports local processing
time and the number of planning frames at a simulated FPS, rather than sleeping
between frames. `--repeat 2` compares the first and repeated plan;
`--move-yards 50` changes the start between runs; `--revision COMMIT` compares an
older implementation. The per-module metrics are inclusive and overlap; they
must not be added together. These measurements exclude game rendering and are
not promises about in-client timing. For example, one local 323-node run at a
simulated 60 FPS improved from 11.08 to 6.20 seconds initially and from 10.72 to
0.13 seconds on repetition, with 64 locations included in both versions. A
different valid detour can change incidental nearby-node coverage; all required
farming-area approaches and terrain checks remain enforced.

## Regeneration

Install `requirements-dev.txt`, then run from the repository root:

```sh
python tools/build_terrain.py --snapshot-root ../output/forever-datamine-70959
python tests/run_tests.py
python tools/verify_terrain_routes.py --nodes path/to/node-report.json
```

The snapshot must contain the copied CASC `Data` directory and decoded root and
encoding metadata described in `tools/terrain/local_casc.py`. Compact map bounds
and WDT identifiers are versioned in `tools/terrain/zones.json`. The reader
validates content hashes and supports this build's N/Z BLTE records; unsupported
records fail closed. Outputs are `Data/Terrain.lua` and the separate
`../output/terrain-overlays-70959` gallery/inventory. No game-install files change.
If extraction rules change, use a new `--artifacts` directory to avoid retaining
processed tile masks from older rules.
