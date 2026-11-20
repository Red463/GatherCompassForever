# Changelog

## 1.1.0 - 2026-11-20

This entry includes all changes since 1.0.0, including the 1.0.1 gathering-reference update.

### Terrain-aware routes and performance

- Supply terrain overlays for all 55 local zones in Forever build 70959 (43 complete and 12 with restricted missing sections). Use the final Ashenvale rules: 50-degree slope cutoff, isolated one/two-cell restriction cleanup, enclosed-pocket filling, swimming and necessary backtracking allowed.
- Generate route connections around restricted areas, adding travel waypoints between gathering stops. Apply terrain planning to generation, route starts, rejoining, removal/undo, skips, reversal and Node Codex guidance. Preserve the terrain bends in line routes, heatmaps and arrow guidance.
- Keep generation responsive by spreading work across frames with a soft time budget. Cancel obsolete work on Stop, replacement or zone change and publish completed plans together.
- Speed up path searches with decoded-row caching, precomputed movement costs and a stronger distance heuristic. Reuse bounded path results and proven unreachable connections for repeat generation, while invalidating changed masks and never caching exhausted search budgets.
- Show a prominent animated Generating route message in the addon window, disable generation buttons while work is pending and add Cancel generation. Cancelling a calculation preserves existing guidance and its gathering session.

### Route sessions and History

- Add a character-specific History tab. A gathering session starts with a route and ends only when Stop is pressed; laps, detours, pauses, replacement guidance, route completion and reloads keep that session open.
- Open the saved session summary on Stop, with its starting route/zone, date, duration, successful gathering actions and received quantities of each item. Keep Stop available for an open session even when no follower was restored after a reload.
- Track actual received herbs, ores and bonus items from confirmed gathering actions, including repeated mining taps. Reject duplicate notifications, uncollected loot and unrelated sources; handle late confirmations without attributing old receipts to a new session.
- Optionally save Auctionator prices at Stop and show estimated gross auction value with explicit unpriced-item coverage. Omit valuation when Auctionator is absent, and retain each historical session's original price snapshot.

### Navigation fixes and diagnostics

- Preserve the current route leg, direction and lap progress after position dropouts and Resume. Reconnect to the current target instead of choosing an earlier nearby waypoint that could rewind or reverse guidance.
- Keep guidance active when the player steps into a blocked overlay cell. The mask constrains planned paths; a blocked current player cell no longer hides the arrow or prevents Resume, recovery, arrival or Skip.
- Respect the selected arrival radius for resource stops even when the following leg needs a detour. Keep the movement guard for overlapping stops and corner protection for required travel bends.
- Show linked resource names on the arrow instead of Farming corridor, including through terrain detours and in either route direction.
- Render the arrow below normal windows and dialogs so it no longer covers the Gatherly panel.
- Add opt-in /gatherly trace diagnostics for position/arrow dropouts, mask/path reasons and unchanged recovery. /gatherly trace report opens a copyable bounded report and stops recording.

### Display and minimap controls

- Replace world-map and minimap icon/outline size menus with sliders from 4 to 32 in whole-number steps. Show plain size values without pixel units and refresh previews immediately.
- Label icon and outline opacity sliders explicitly, using Icon opacity within each map tab.
- Apply the floating route-colour selector to minimap line routes as well as heatmaps, remembering the choice across route-style changes.
- Restore the standard native minimap border/background and scale the complete launcher badge to collected button sizes.
- Request EQoL Button Sink discovery after launcher/minimap visibility and addon/login changes. Preserve collector-owned placement, honour ignored buttons and disabled sinks, and avoid a missed scan leaving the button attached to the minimap.

### Gathering references, documentation and verification

- Align supported gathering resources with Mastercraft 2.0.7's minimum-relative skill-colour model, including starter-node transitions at 26/51/101. Use its plain skill-up wording, including Always a skill-up for orange, while retaining profession caps, bonuses and unknown-data handling. This is reference guidance rather than verified server percentages.
- Replace interface previews with supplied in-game screenshots, retain their original version labels and keep separately labelled diagrams for coverage, route order and minimap heat. Update installation, terrain-routing, History and optional Auctionator documentation.
- Add route-generation benchmarks, independent blocked-cell geometry audits and regressions for terrain rules, recovery, nearby waypoints, session accounting, character isolation, price snapshots, minimap collection and planning feedback.

## 1.0.1 - 2026-11-20

- Align supported gathering resources with Mastercraft 2.0.7's minimum-relative skill-colour model, including starter-node transitions at 26/51/101.
- Use its plain skill-up guidance, including “Always a skill-up” for orange, and identify the Mastercraft reference model in map and Codex source labels. Profession caps, bonuses and unknown-data handling remain supported.

## 1.0.0 - 2026-11-19

- First 1.0 release package for WoW Forever 1.60.1, with the existing MIT license and saved-data format.
- Fix minimap launcher conflicts with EQoL Button Sink: collected buttons keep their manager-owned position, size and visibility; minimap drag logic stops while collected and works again after release.
- Make the launcher artwork follow its button size, preserve unrelated update handlers, and honour the Gatherly visibility preference when a collector shows the button.
- Add collector lifecycle regressions and a CurseForge submission kit containing the addon ZIP, supplied square icon, project description and changelog.

## 0.18.6 - 2026-11-19

- Reduce recurring heatmap memory allocation by reusing density/fade arrays, strip records and modern gradient colour objects after warmup. Keep the smooth renderer and its colour/opacity settings.
- Skip hidden world-marker work and refresh those markers immediately when the world map opens.
- Cull minimap candidates before distance calculations, sorting and grouping, while preserving the pin-library fallback for unsupported shapes or unavailable geometry. Cache matching node lists by database revision, zone and filter.
- Add allocation, colour reuse, selection invalidation, world-map reopening and minimap-work regressions, plus a reproducible offline refresh profiler. Native client hitch reduction still needs confirmation.

## 0.18.5 - 2026-11-19

- Reduce blocky minimap heat and hard opacity bands by replacing coarse flat-colour squares with thin strips and shared, interpolated horizontal edge samples.
- Support both texture-gradient APIs, with a safe fine-strip fallback, and disable independent texture pixel snapping where available to reduce seams.
- Reuse geometry and paint state within a bounded 3,072-texture pool. Preserve colours, opacity controls, player/destination clearance, map shapes and world-map rendering.
- Add a deterministic banding regression, gradient-compatibility tests and a before/after renderer comparison.

## 0.18.4 - 2026-11-19

- Restyle floating route controls as a 272 x 64 Classic toolbar using native dialog trim and the main panel background artwork where available.
- Keep text at its normal size and place Stop, Open panel, Skip and the heatmap-colour swatch in one row. Hover for full control descriptions.
- Keep colour names readable in a full-width popup while reducing its launcher to a swatch. Saved position, colour, guidance and auto-open settings are preserved.

## 0.18.3 - 2026-11-19

- Add a Heatmap colour menu and current-colour swatch to the movable route controls. Choose Amber, Yellow, Cyan, Pink, Green or White to suit minimap terrain.
- Apply and remember colour changes immediately without restarting guidance, changing opacity or recolouring world-map heat. Amber restores the original density tint.

## 0.18.2 - 2026-11-19

- Default world-map heatmap opacity to 50%. Preserve saved opacity choices and all other overlay defaults.

## 0.18.1 - 2026-11-19

- Show movable route controls automatically when guidance starts, with Stop route, Open panel and Skip next node.
- Remember the control panel position and keep it available during paused or suspended guidance; hide it when guidance ends.
- Add Show route controls to Routes so the floating panel can be disabled without changing guidance.

## 0.18.0

- Generate a shared centre-path corridor for Lines and Heatmap. Count selected known locations within 90% of the client-measured fully zoomed-out minimap radius, including locations outside the narrower painted band. Preserve coverage of the previously included local nodes and the 450-yard connection/closure limit.
- Require readable zoomed-out range for new corridor generation and reject unusable numeric scales safely. Keep the captured range through zoom changes and removal/undo; show it in Routes and add arrow reminders for zooming in or a reduced live range. Failed generation leaves existing guidance intact.
- Use travel-only corridor guidance with optional resource detours; confirmed gathers continue updating personal history. Preserve legacy gather-stop behavior and direct Node Codex nearest-resource guidance.
- Add independent Line and Heatmap opacity on World map and Minimap, including the Routes sketch. Migrate prior minimap opacity, preserve explicit zero, and keep marker opacity independent.
- Strengthen red corridor heat with continuous bounded sampling and soft edges; retain amber minimap heat, shape masks and tracking clearance. Reject excessive geometry before publishing an incomplete overlay.

## 0.17.0

- Optimize generated route order with a bounded 2-opt pass and remove redundant travel-only stops. Reduce avoidable crossings and backtracking while keeping every currently included farming area, its gather identity and the nearest start.
- Preserve the 450-yard limit for every connection and final closure. Required branch returns remain; geometric routes still cannot determine terrain passability.
- Use the optimized plan for both Lines and Heatmap, the guide arrow and removal/undo rebuilds. Existing active routes remain intact until explicitly replaced.
- Add route-quality, narrow-branch, coverage, metadata and rebuild tests, plus a synthetic before/after example. Fixed sample circuits are 16–21% shorter; results vary with node layout and connection constraints.

## 0.16.4

- Brighten minimap heat to amber/gold and strengthen sparse corridor centres so guidance stands out over dark forest, cave and swamp terrain. Preserve soft edges, player/destination clearance and the existing overlay opacity control.
- Keep world-map heat unchanged. Add rendered-colour contrast checks at the default minimap opacity and refresh the dark-terrain preview.

## 0.16.3

- Make the world-map heat corridor clearer by accounting for the actual faded heat texture when balancing overlapping patches. Keep soft edges and readable terrain at crossings; apply the same correction to the Routes preview.
- Preserve minimap heat appearance. Add visibility checks that compose the shipped texture with the Lua renderer across straight sections, bends and dense crossings.

## 0.16.2

- Move the active-route map-marker checkbox from Node display to Routes and rename it to “Only show route target nodes during an active route.”
- Add a tooltip explaining both-map filtering, saved route selections and restoration of normal markers after Stop/completion. Preserve the saved setting and existing behavior.

## 0.16.1

- Remove the artificial 40-row/0.1-second import limit. Imports now use their own per-frame coroutine with a soft 4ms budget and a work cap for missing or frozen timers.
- Use a disposable spatial index for duplicate checks, retaining first-match order, the 5-yard merge radius, aliases, object separation and personal gather history.
- Rebuild indexes after live gathers or changed zone metrics, and yield during large index construction. Release temporary state after completion/errors.
- Avoid distance API calls for exact repeat locations and cache resource names by type/ID during each import.
- Refresh the panel/maps immediately when an import finishes and keep route guidance on its independent tick. Preserve partial-error retry and all-zone coverage.
- Add a repeatable synthetic first/repeat import benchmark with stored-node-count validation.
- Preserve inclusive five-yard matches at floating-point cell boundaries, use exact-coordinate indexing when native map dimensions are unavailable, and protect timer fallbacks. Resume tokens revalidate metrics independently of the game clock.

## 0.16.0

- Rename the addon, folder, TOC, saved-variable namespace, slash command, frame identifiers, repository links and packages to Gatherly. The command is now /gatherly.
- Replace the project artwork with the supplied Gatherly logo and badge, preserving transparency and whole-image proportions.
- Refresh current documentation and image examples for Gatherly, with no runtime aliases for former names.
- Provide an offline saved-data transfer tool that preserves the data payload and source file while refusing to overwrite an existing destination.

## 0.15.1

- Fix logo framing: remove the 0.17-0.83 UV crop that enlarged the badge and cut into the compass artwork.
- Fit the complete supplied badge inside the panel's native portrait frame.
- Show the complete 32px minimap badge using its own transparent silhouette and gold compass border; remove the extra node ring, circular clipping mask and background disc.
- Preserve supplied source artwork, panel sizing, launcher clicks and dragging.

## 0.15.0

- Replace free panel resizing with Small (960 x 680), Standard (1100 x 780) and Large (1240 x 880) layouts selected in Preferences. Remove the corner resize grip.
- Keep normal text and control sizes unchanged, enlarge the route map and lists with each layout, and preserve map artwork proportions and marker alignment.
- Migrate saved dimensions to the nearest preset without changing panel position, route progress or filters.
- Fit oversized choices to a smaller preset temporarily; restore the chosen size when screen space returns. Scale the whole panel only when even Small cannot fit.
- Update Preferences size/reset instructions and preserve minimising, map zoom/pan, Codex selection and active guidance across size changes.

## 0.14.0

- Remember confirmed detour pickups for the current lap and skip their matching later gather stops in both Lines and Heatmap mode. Reset next lap or on a fresh route start.
- Match resource identity, object identity where available and the nearest planned stop within 15 yards. Reject ambiguous matches and duplicate object loot; retain explicit and necessary travel connections.
- Preserve pickup memory through pause, rejoin, reverse and in-session node removal/undo without deleting node history or changing marker selections.
- Bind gather confirmation to its originating route and lap, prefer an existing spawn's identity, and retain lap coverage through rejoin/reverse so pickups reset after the circuit is accounted for.
- Use the most common resource's icon for grouped world-map, minimap and route-review markers, with stable ties and unchanged marker positions.
- Simplify grouped hover details to skill-coloured resource names and right-aligned counts. Keep detailed single-node tooltips.
- Replace the Welcome subtitle with functional instructions and update marker previews to match the new group style.

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
