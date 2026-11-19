# Changelog

## 0.13.0

- Separate everyday Map markers from Route targets, migrating existing selections into independent copies. Add Visible nodes settings and an optional route-filter snapshot override that restores everyday markers on Stop/completion.
- Darken heat corridors with bounded composited opacity. Replace per-spawn minimap heat cutouts with small feathered player/destination clearance; retain known-node gaps for thin lines.
- Replace Codex tile and ranked-zone pagination with recycled vertical scrolling, preserving query/Back/reflow position and all custom resources.
- Mark confirmed missing gathering professions red, while unreadable ranks or incomplete queries remain neutral. Refresh on skill changes.
- Group Preferences into Navigation, Guide arrow and Panel & minimap, with a live explanation of the waypoint arrival radius.
- Include the runtime version in the title bar; show map artwork behind the marker appearance example.
- Centre the portrait slot/mask and minimap icon/ring, using a tighter crop of the original high-resolution emblem without changing source artwork.
- Preserve resource-only override snapshots through Codex review/start/rebuild and all route-eligible vein variants. Keep independent selections through imported material-ID promotion.
- Explain invisible/overridden Codex map actions, prefer installed version metadata, and avoid unused line-clearance scans in heat mode.
- Preserve panel resizing, routes, node history, navigation behaviour and MIT licensing.

## 0.12.0

- Add a draggable bottom-right panel resize grip with saved width, height and screen-relative position. Keep normal text, controls and guide-arrow size unchanged.
- Grow the Routes map and material viewport with the panel; wrap generation actions at narrow widths.
- Reflow Node Codex filters and adjust resource/zone page capacity to available space.
- Keep Welcome, Node display and full-width Preferences accessible through interior scrolling when needed.
- Add the current dimensions and Reset panel size in Preferences. Default size is 960 x 624, minimum layout 860 x 600 UI units, with screen fitting below that minimum.
- Preserve untouched size/position preferences on fitted grip clicks, keep the opposite corner fixed at screen edges, and retain custom Codex resources across responsive pages.
- Preserve preferred size through resolution changes and minimise/expand, close stale popups on resize, and keep route state and map zoom/pan intact.

## 0.11.0

- Group overlapping world-map, minimap and review icons into shared count badges with coloured resource breakdowns. Keep minimap outlines at their exact spawn coordinates.
- Add an individual member chooser for grouped review nodes, preserving single-node removal and undo.
- Combine Atlas and Resources into Node Codex: full skill-coloured catalogue, type/skill/source/zone browsing, ranked zones, history and guarded local route/nearest actions; remove coordinate lists and the redundant Welcome button.
- Simplify Node display into full-width World map and Minimap pages, with previews and migrated appearance values.
- Make Welcome step 2 open Routes with Choose materials.
- Add structured skill-coloured panel tooltips for materials, resources and grouped nodes.
- Show active heat corridors on the minimap with bounded opacity, known-node/player clearance, standard-shape masks and effective rotation support. Stop/completion clears the overlay.
- Reveal supported Routes map artwork using pinned attributed MIT metadata from OpenMap; load textures from the installed client and fall back to native explored art for unsupported map-art IDs.
- Keep existing storage, routing/session ownership, shared filters, arrow behaviour and MIT licensing. No new addon dependency or copied client artwork.
- Keep scoped Codex colours tied to matching sources, cache warm queries, and disable map actions when shared selections have no matching locations.
- Keep review pickers consistent with changed selections and allow exactly coincident members to be selected even with grouping disabled.
- Clear previous-phase reveal tiles and preserve square-minimap corner icons; align markers and heat when Forever ignores minimap rotation.

## 0.10.0

- Add one-time Gatherable material selection, including eligible grey resources and capped professions.
- Replace the saved-route/manual creation workflow with Generate & start and Generate & review; preserve existing saved data.
- Add a larger map-backed review with node selection, Remove node, Undo removal, mouse-wheel zoom and right-drag pan.
- Add Lines and Heatmap corridor views of the same plan. Heat replaces world-map lines and suppresses minimap route lines.
- Generate a bounded nearby farming corridor through representative spawn locations, with included/omitted counts and no long closing jump.
- Fix the reproduced nearest-start then distant-next-leg transition; orient generated loops toward the nearer outgoing side.
- Preserve pause state and lap display when a node removal rebuilds active guidance. Filter changes leave the active plan intact until regeneration.
- Validate local joins on resume and coordinate recovery, keep failed edits intact, and count laps from the joined waypoint in either direction.
- Clear all path views on Stop/completion, keep Atlas guidance independent, and bound dense-map drag work.
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
