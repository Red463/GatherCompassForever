"""Verify the first-release upload kit without contacting CurseForge."""
from pathlib import Path
import json
import re
import struct

root = Path(__file__).resolve().parents[1]
dist = root / 'dist'
data = json.loads((dist / 'Gatherly-1.0.0-Submission.json').read_text())
assert data['version'] == '1.0.0' and data['project'] == 'Gatherly'
assert data['flavour'] == 'Forever' and data['gameVersions'] == ['1.60.1']
assert data['releaseType'] == 'Release' and data['license'] == 'MIT License'
for key in ('archive', 'icon', 'description', 'changelog'):
    path = dist / data[key]
    assert path.parent == dist and path.is_file(), key
icon = (dist / data['icon']).read_bytes()
assert icon == (root / 'assets/source/Gatherly Badge.png').read_bytes(), 'Supplied icon must remain unchanged'
assert icon.startswith(b'\x89PNG\r\n\x1a\n')
w, h = struct.unpack('>II', icon[16:24])
assert w == h and w >= 400
description = (dist / data['description']).read_text(encoding='utf-8')
assert description == (root / 'docs/curseforge-description.md').read_text(encoding='utf-8')
assert 'not in-game screenshots' in description and '16001' in description
for image in re.findall(r'https://raw.githubusercontent.com/Red463/Gatherly/v1\.0\.0/([^\s)]+)', description):
    assert (root / image).is_file(), image
changes = (dist / data['changelog']).read_text(encoding='utf-8')
assert changes.startswith('## Gatherly 1.0.0\n') and 'EQoL' in changes and '## 0.' not in changes
print(f'CurseForge kit: version, client flavour, Release type, MIT, {w}x{h} original icon and description/changelog verified')
