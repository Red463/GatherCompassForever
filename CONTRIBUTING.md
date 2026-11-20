# Contributing

To profile all-zone import throughput, run `python tools/benchmark_import.py --rows 20000`.
The synthetic harness exercises the real provider, store and Core scheduler, with UI/map
rendering replaced by counters. It reports both processing time and simulated 60 Hz
completion time for first/repeat imports, checks the stored node count, and counts
distance/name lookups. Timings depend on the machine and are not native-client measurements.

Bug reports and pull requests are welcome.

For a bug, include the addon version, Forever client build, zone, steps to reproduce,
expected behavior and any Lua error text. A screenshot or short recording is useful
for map, marker and arrow issues. Remove character/account details you do not want
to share publicly. Do not upload your WTF folder or SavedVariables.

## Local checks

Use Python 3.13 or newer. Run these commands from the repository root:

```sh
python -m pip install -r requirements-dev.txt
python tests/run_tests.py
python tools/package.py
python tests/package.py
python tools/check_publication.py
```

The runner uses Lupa's Lua 5.1 backend and compiles every TOC entry. Tests run with
fake game UI/API objects; they do not prove native client rendering or protected
API behavior. Check relevant changes inside Forever too.

The ZIP in `dist/` is generated output. Do not commit build ZIPs or dependency
caches. Keep runtime files in the explicit TOC/packaging manifest.

Terrain generation and the independent route audit are documented in
[terrain routing](docs/terrain-routing.md). Use a copied client snapshot for
extraction; keep raw client data and node reports out of the repository.
Use `python tools/benchmark_routing.py --nodes path/to/node-report.json` to compare
planning latency and cache reuse. Its frame-time model and inclusive metrics are
described in the terrain-routing document.

## Artwork and examples

Original brand images are in `assets/source/`; their WoW TGA conversions are in
`Media/`. Geometric marker/arrow generation is in `tools/`. Rebuild supplied artwork
with `python tools/build_branding.py` only when you intend to update those assets.

`python tools/render_ui_preview.py` creates illustrative layouts from the real Lua
frame tree. The preview scripts currently use Windows system fonts and substitute
native textures. These previews are not in-game screenshots and belong in the
ignored `docs/previews/` directory. Curated in-game screenshots are in
`docs/images/`; preserve their original pixels and visible version labels. Generated
technical diagrams in that directory must stay clearly labelled as illustrations.
Include a real screenshot when reporting a native rendering issue.

## Scope and licensing

Preserve existing saved data and keep optional/missing game APIs safe. Do not bundle
third-party spawn datasets or automate character movement/gathering. Keep node
history distinct from live spawn availability.

Contributions are supplied under the project's MIT license unless clearly stated
otherwise. Keep bundled library copyright and license notices intact; see `NOTICE.md`.
