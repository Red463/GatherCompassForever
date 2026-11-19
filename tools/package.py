"""Build only the explicit runtime manifest; no staging deletion or client writes."""
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[1]
toc = root / 'Gatherly.toc'
files = ['Gatherly.toc', 'README.md', 'NOTICE.md', 'LICENSE', 'CHANGELOG.md', 'CONTRIBUTING.md',
         'Libs/LICENSE.txt', 'Libs/HereBeDragons-LICENSE.txt','Libs/OpenMap-Reveal-LICENSE.txt',
         'Media/Icon.tga','Media/Header.tga','Media/LogoSheet.tga','Media/EmptyEmblem.tga','Media/README.txt','Media/NodeRing.tga','Media/NodeSquare.tga','Media/GuideArrow.tga','Media/HeatBlob.tga','Media/MinimapMasks.tga']
files += [line.strip() for line in toc.read_text().splitlines()
          if line.strip() and not line.startswith('#')]
files += [p.relative_to(root).as_posix() for p in sorted((root / 'docs/images').glob('*.png'))]
for name in files:
    assert (root / name).is_file(), f'Missing package file: {name}'
dist = root / 'dist'
dist.mkdir(exist_ok=True)
path = dist / 'Gatherly-0.18.3.zip'
with zipfile.ZipFile(path, 'w', zipfile.ZIP_DEFLATED) as z:
    for name in files:
        z.write(root / name, 'Gatherly/' + name)
print(f'Packaged {path} ({path.stat().st_size:,} bytes)')
