"""Build only the explicit runtime manifest; no staging deletion or client writes."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
toc = root / 'GatherCompassForever.toc'
files = ['GatherCompassForever.toc', 'README.md', 'NOTICE.md', 'LICENSE', 'CHANGELOG.md', 'CONTRIBUTING.md',
         'Libs/LICENSE.txt', 'Libs/HereBeDragons-LICENSE.txt',
         'Media/Icon.tga','Media/Header.tga','Media/LogoSheet.tga','Media/EmptyEmblem.tga','Media/README.txt','Media/NodeRing.tga','Media/NodeSquare.tga','Media/GuideArrow.tga']
files += [line.strip() for line in toc.read_text().splitlines()
          if line.strip() and not line.startswith('#')]
files += [p.relative_to(root).as_posix() for p in sorted((root / 'docs/images').glob('*.png'))]
for name in files:
    assert (root / name).is_file(), f'Missing package file: {name}'
dist = root / 'dist'
dist.mkdir(exist_ok=True)
path = dist / 'GatherCompassForever-0.8.6.zip'
with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in files:
        z.write(root / name, 'GatherCompassForever/' + name)
print(f'Packaged {path} ({path.stat().st_size:,} bytes)')
