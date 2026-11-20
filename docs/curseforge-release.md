# Gatherly 1.0.0 submission brief

The release kit is prepared locally; it does not create or publish a CurseForge project.

| Field | Value |
| --- | --- |
| Project name | Gatherly |
| Summary | Herb and ore locations, resource information and farming route guidance. |
| Game / class | World of Warcraft / Addons |
| Suggested main category | Professions |
| Suggested additional category | Map & Minimap |
| License | MIT License |
| Source | https://github.com/Red463/Gatherly |
| Issues | https://github.com/Red463/Gatherly/issues |
| Release name | Gatherly 1.0.0 |
| Release type | Release |
| Client flavour | Forever |
| Game version | 1.60.1 |
| TOC interface | 16001 |

Run `python tools/package.py`, then `python tools/prepare_curseforge_release.py`.
The generated submission JSON is a reference sheet, not a CurseForge API payload.

Upload `dist/Gatherly-1.0.0.zip` as the addon file. Its single top-level folder is
`Gatherly/`, containing `Gatherly.toc`; do not upload GitHub's source-code archive.
The ZIP includes runtime files, documentation, project artwork and all required
third-party licence notices. Development tools, tests, local dependencies and
compatibility-research downloads are excluded.

Use `dist/Gatherly-CurseForge-Icon.png` as the project icon. It is an unchanged copy
of the supplied square 1254 x 1254 PNG. Paste
`dist/Gatherly-CurseForge-Description.md` into the Markdown description editor and
`dist/Gatherly-1.0.0-Changes.md` into the release changelog.

GatherMate2 and GatherMate2_Data are optional import sources. EQoL is an optional
button collector. No required external addon dependency is introduced.
Choose the matching Forever files if adding optional project relations.

Compatibility is covered by regression tests for EQoL-style collection, repeated
minimap callbacks, collapsed containers, dragging, return to the minimap and
visibility changes. This does not replace a final in-game check with the installed
EQoL version. Existing Gatherly SavedVariables remain compatible.

The interface gallery uses supplied in-game screenshots captured on v0.18.6.
Keep the original version labels and settings visible; they may differ from the
current release. Coverage, route-order and minimap-smoothing diagrams in the README
remain labelled as generated illustrations. Documentation image links follow
the main branch; existing release tags and uploaded assets remain unchanged.

References:

- [CurseForge project submission guide](https://support.curseforge.com/support/solutions/articles/9000199552-project-submission-guide-and-tips) — icon dimensions, description formats and licence selection.
- [EQoL Forever 13.23.0 file](https://www.curseforge.com/wow/addons/eqol/files/9680343) — compatibility-reference release for Forever 1.60.1.
