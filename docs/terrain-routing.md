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
Automatic recovery uses a smaller search budget and can suspend until the player
moves nearer or chooses Resume. Missing data, unreachable paths and exhausted
budgets produce explanations instead of straight-line fallback guidance.

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
