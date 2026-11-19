from pathlib import Path
import zipfile
root = Path(__file__).resolve().parents[1]
path = root / 'dist/GatherCompassForever-0.15.0.zip'
assert path.is_file(), 'Installable ZIP missing'
with zipfile.ZipFile(path) as z:
    names = z.namelist()
    assert names and all(n.startswith('GatherCompassForever/') for n in names)
    assert not any('/tests/' in n or '/dev/' in n or '/tools/' in n or '/.test-deps/' in n for n in names)
    toc = z.read('GatherCompassForever/GatherCompassForever.toc').decode()
    metadata = dict(line[3:].split(': ', 1) for line in toc.splitlines() if line.startswith('## '))
    assert metadata['Title'] == 'Gather Compass Forever'
    assert metadata['SavedVariables'] == 'GatherCompassForeverDB'
    assert metadata['Version'] == '0.15.0'
    assert metadata['X-License'] == 'MIT'
    assert metadata['IconTexture'] == r'Interface\AddOns\GatherCompassForever\Media\Icon'
    for texture in ['Icon', 'LogoSheet', 'EmptyEmblem', 'NodeRing', 'NodeSquare', 'GuideArrow', 'HeatBlob', 'MinimapMasks']:
        assert f'GatherCompassForever/Media/{texture}.tga' in names
    for line in toc.splitlines():
        if line.strip() and not line.startswith('#'):
            assert 'GatherCompassForever/' + line.strip().replace('\\','/') in names, line
    for file in ['LICENSE','CHANGELOG.md','CONTRIBUTING.md','NOTICE.md','README.md','Libs/LICENSE.txt','Libs/HereBeDragons-LICENSE.txt','Libs/OpenMap-Reveal-LICENSE.txt','Media/Icon.tga','Media/Header.tga']:
        assert 'GatherCompassForever/' + file in names
    assert z.read('GatherCompassForever/LICENSE').startswith(b'MIT License')
    assert b'Copyright (c) 2026 OpenMap contributors' in z.read('GatherCompassForever/Libs/OpenMap-Reveal-LICENSE.txt')
    assert 'GatherCompassForever/Data/MapReveal.lua' in names
    assert 'GatherCompassForever/AtlasView.lua' not in names
    mask=z.read('GatherCompassForever/Media/MinimapMasks.tga')
    assert mask[2]==2 and mask[16]==32 and int.from_bytes(mask[12:14],'little')==256
    for path in (root / 'docs/images').glob('*.png'):
        assert 'GatherCompassForever/' + path.relative_to(root).as_posix() in names
    for marker in ['NodeRing', 'NodeSquare']:
        data = z.read(f'GatherCompassForever/Media/{marker}.tga')
        assert data[2] == 2 and int.from_bytes(data[12:14], 'little') == 64
        assert int.from_bytes(data[14:16], 'little') == 64 and data[16] == 32
        pixels = data[18:18+64*64*4]
        assert pixels[(32*64+32)*4+3] == 0, 'Marker centre must stay transparent'
        assert max(pixels[3::4]) == 255, 'Marker outline missing'
    heat = z.read('GatherCompassForever/Media/HeatBlob.tga')
    assert heat[2] == 2 and heat[16] == 32
    size = int.from_bytes(heat[12:14], 'little')
    assert size == 128 and int.from_bytes(heat[14:16], 'little') == size
    alpha = heat[18:18+size*size*4][3::4]
    assert alpha[size//2*size+size//2] > 250 and alpha[0] == 0
    for name in names:
        if name.endswith(('.lua','.md','.txt','.toc')):
            assert b'estimat' not in z.read(name).lower(), f'Prohibited wording in shipped file: {name}'
    assert z.testzip() is None
    for name in names:
        relative = name.removeprefix('GatherCompassForever/')
        assert z.read(name) == (root / relative).read_bytes(), f'Stale packaged file: {relative}'
print(f'Package: {len(names)} entries, layout, runtime files, licences and exclusions verified')
