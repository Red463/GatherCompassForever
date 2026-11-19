# Gatherly

Herb and ore locations, resource information and farming route guidance for **WoW Forever 1.60.1**.

![Gatherly logo](https://raw.githubusercontent.com/Red463/Gatherly/v1.0.0/docs/images/logo.png)

## Locations and materials

- Remember personally gathered herb and ore locations across characters.
- Import all-zone data from installed GatherMate2_Data, with GatherMate2 observations as a fallback.
- Choose the sources, gathering types and materials you want on your maps or in a route.
- Show world-map resource icons and minimap icons, hollow rings or squares, with skill colours, grouping and opacity controls.
- Browse Node Codex for resource requirements, recorded gathering history and zones ranked by known locations.

## Farming routes

Select materials, then **Generate & start** or **Generate & review**. The review map lets you remove unwanted nodes and undo changes.

Follow a line or heatmap corridor with a smooth gold guide arrow. A compact movable toolbar provides Stop, Open panel, Skip and a minimap heatmap colour swatch. Confirmed detour gathers count for the current lap.

Map-marker selections are independent of route targets. An optional route override shows only tracked nodes while following. The minimap launcher supports collection by EQoL Button Sink.

**Routes use geometric connections. Terrain can require a detour; the addon does not move your character or gather automatically. Known locations are possible spawns, not live node availability.**

## Interface examples

These are layout previews rendered from Gatherly's Lua UI, with approximate native textures and fonts. They are not in-game screenshots.

![Route review](https://raw.githubusercontent.com/Red463/Gatherly/v1.0.0/docs/images/routes.png)

![Node Codex](https://raw.githubusercontent.com/Red463/Gatherly/v1.0.0/docs/images/node-codex.png)

## Getting started

1. Install the Gatherly folder and enable the addon.
2. Type **/gatherly** or click the minimap badge.
3. Use **Welcome** to import installed node data, or gather normally to record your discoveries.
4. Choose materials in **Routes**, then generate a route.

No other addon is required for personal recording or guidance. Importing external locations requires compatible data addons; those datasets are not bundled. EQoL is optional. This release supports Forever's interface **16001**; Retail and other Classic clients are not supported.

## Support and source

Please report the addon version, client build, zone, steps to reproduce and any Lua error. For performance alerts, include a fresh report after clearing the monitor's history.

[Report an issue](https://github.com/Red463/Gatherly/issues) | [Source and full documentation](https://github.com/Red463/Gatherly)

Original Gatherly code and artwork are MIT licensed. Bundled libraries and map-reveal metadata retain their own licence notices. World of Warcraft and native UI artwork belong to Blizzard Entertainment.
