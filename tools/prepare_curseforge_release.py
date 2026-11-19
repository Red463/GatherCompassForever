"""Prepare upload assets without publishing or changing supplied artwork."""
from pathlib import Path
import json
import shutil
import struct

root = Path(__file__).resolve().parents[1]
metadata = dict(line[3:].split(': ', 1) for line in (root / 'Gatherly.toc').read_text().splitlines() if line.startswith('## '))
version = metadata['Version']
dist = root / 'dist'
archive = dist / f'Gatherly-{version}.zip'
assert archive.is_file(), 'Build the addon ZIP with tools/package.py first'
assert metadata['Interface'] == '16001' and metadata['X-License'] == 'MIT'
dist.mkdir(exist_ok=True)
icon = root / 'assets/source/Gatherly Badge.png'
data = icon.read_bytes()
assert data.startswith(b'\x89PNG\r\n\x1a\n')
width, height = struct.unpack('>II', data[16:24])
assert width == height and width >= 400, 'CurseForge project icon must be square and at least 400 pixels'
shutil.copyfile(icon, dist / 'Gatherly-CurseForge-Icon.png')
shutil.copyfile(root / 'docs/curseforge-description.md', dist / 'Gatherly-CurseForge-Description.md')
changelog = (root / 'CHANGELOG.md').read_text(encoding='utf-8')
entry = changelog.split(f'## {version} - ', 1)[1].split('\n## ', 1)[0]
changes = f'## Gatherly {version}\n\n' + entry.split('\n', 1)[1].lstrip()
(dist / f'Gatherly-{version}-Changes.md').write_text(changes, encoding='utf-8')
submission = dict(project='Gatherly', version=version, game='World of Warcraft', flavour='Forever',
                  gameVersions=['1.60.1'], releaseType='Release', license='MIT License',
                  archive=archive.name, icon='Gatherly-CurseForge-Icon.png',
                  description='Gatherly-CurseForge-Description.md', changelog=f'Gatherly-{version}-Changes.md',
                  source='https://github.com/Red463/Gatherly', issues='https://github.com/Red463/Gatherly/issues')
(dist / f'Gatherly-{version}-Submission.json').write_text(json.dumps(submission, indent=2)+'\n', encoding='utf-8')
print(f'CurseForge {version} kit prepared; original {width}x{height} icon preserved. No upload performed.')
