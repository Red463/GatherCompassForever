from pathlib import Path
import os
import runpy
import sys

root = Path(__file__).resolve().parents[1]
try:
    from lupa.lua51 import LuaRuntime
except ImportError:
    sys.path.insert(0, str(root / '.test-deps'))
    from lupa.lua51 import LuaRuntime
os.chdir(root)
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((root / 'tests/run.lua').read_text(encoding='utf-8'))
toc = root / 'Gatherly.toc'
if toc.exists():
    names = [s.strip() for s in toc.read_text().splitlines() if s.strip() and not s.startswith('#')]
    for name in names:
        assert (root / name).is_file(), name
        lua.execute('assert(loadfile(...))', str(root / name))
    print(f'TOC: {len(names)} files compile under Lua 5.1')

runpy.run_path(str(root / 'tests/heatmap_visibility.py'), run_name='__main__')
runpy.run_path(str(root / 'tests/minimap_heat_visibility.py'), run_name='__main__')
