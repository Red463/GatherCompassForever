# Changelog

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
