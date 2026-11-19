# Changelog

## 0.10.0

- Add one-time Gatherable material selection, including eligible grey resources and capped professions.
- Replace the saved-route/manual creation workflow with Generate & start and Generate & review; preserve existing saved data.
- Add a larger map-backed review with node selection, Remove node, Undo removal, mouse-wheel zoom and right-drag pan.
- Add Lines and Heatmap corridor views of the same plan. Heat replaces world-map lines and suppresses minimap route lines.
- Generate a bounded nearby farming corridor through representative spawn locations, with included/omitted counts and no long closing jump.
- Fix the reproduced nearest-start then distant-next-leg transition; orient generated loops toward the nearer outgoing side.
- Preserve pause state and lap display when a node removal rebuilds active guidance. Filter changes leave the active plan intact until regeneration.
- Keep Welcome as the sole import page and update its introduction for the new workflow.
- Keep MIT licensing and no new dependency. Geometry does not establish terrain passability; mountains, caves and walls may still need detours.

## 0.9.0

- Replace node-source and gathering dropdowns with combinable checkboxes, including explicit empty selections.
- Share source, gathering and material filters between both maps and new route generation.
- Add All and one-time Skill-ups material selection, retaining individual edits and skill colours.
- Replace material pages with a vertically scrolling list and Classic scrollbar.
- Add a first-use Welcome tab with introduction, import progress and the sole import button.
- Preserve saved data, active guidance, editor drafts, marker opacity and native minimap tracking clearance.

## 0.8.8

- Make Gathering filter node markers on both the world map and minimap: Herbs, Ore or Both.
- Apply type changes immediately and clear older resource-map focus.
- Keep minimap tracking-dot clearance for hidden node types and preserve current guidance.

## 0.8.7

- Add independent 0-100% opacity sliders for world-map icons, minimap icons and minimap outlines in Node display.
- Apply opacity changes immediately and remember them across sessions.
- Preserve skill colours, nearby-icon hiding and fully visible navigation/editing markers.
- Prevent fully transparent node markers from catching hover.

## 0.8.6

- Apply arrival-distance changes immediately to the current route.
- Remove the fixed advancement delay and extra five-yard approach requirement for nearby distinct waypoints.
- Preserve gathering pauses and protect against stationary overlapping-point loops.
- Rearm coincident stops after leaving their arrival radius rather than travelling from the previous arrival position.

## 0.8.5

- Show world-map route lines only during active navigation or path editing.
- Clear routes after stopping, completing or leaving the editor; opening a saved route's map does not start guidance.
- Use fine gold world-map strokes, a brighter current leg and a subtle contrast edge.
- Keep world-map line widths consistent while zooming and preserve minimap tracking clearance.

## 0.8.4

- Place world-map routes above Blizzard's exploration and highlight pin artwork.
- Respect OpenMap's active stitched-terrain layer while keeping node markers above routes.
- Cover following, editing, terrain tier ranges and unavailable map APIs in regression checks.

## 0.8.3

- Put world-map route strokes on a dedicated layer above map artwork and below pins.
- Add dark outlines and stronger route contrast; keep minimap tracking clearance.
- Keep line outlines aligned during waypoint dragging.
- Clear old resource-only focus when starting or explicitly opening a route.

## 0.8.2

- Add Delete route with a named confirmation and Cancel/Escape support.
- Preserve node history and other routes; stop guidance only for the deleted route.
- Keep replacement selection visible after deletion and revalidate stale confirmations.

## 0.8.1

- Open the world map immediately from Edit path.
- Add gold circular editor handles, selected/hovered waypoint numbers and map instructions.
- Update dragged handles and connecting lines each frame, preserving grab offsets.
- Add map Save route/Route panel controls and safer bounds/drag cleanup.

## 0.8.0

- Add the Resources item grid, type/search filters and detail pages.
- Rank known zones by node count and show source-specific gathering requirements.
- Combine ore item sources, including Small/Rich Thorium, while retaining separate skills.
- Include supported resources with no saved locations and preserve independent route filters.

## 0.7.x

- Turn Node Atlas into an actionable resource guide with skill filters and zone comparisons.
- Colour route material names by profession skill.
- Add a draggable, optional minimap launcher with saved position.
- Generate descriptive, distinct route names from the zone and included resources.

## Earlier versions

Gathering memory, direct all-zone GatherMate2_Data import, custom/generated/recorded
routes, map and minimap markers, smooth guide arrow, optional next-node/step/lap
labels, Classic-style UI, and native tooltip inspection.
