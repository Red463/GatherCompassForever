"""Audit current branding, identifiers and runtime asset paths."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
toc_path = root / 'Gatherly.toc'
assert toc_path.is_file(), 'Renamed TOC missing'
metadata = dict(line[3:].split(': ', 1) for line in toc_path.read_text().splitlines() if line.startswith('## '))
assert metadata['Title'] == 'Gatherly'
assert metadata['SavedVariables'] == 'GatherlyDB'
assert root.name == 'Gatherly', 'Workspace folder has not been renamed'
former = ['Gather' + 'Compass' + 'Forever', 'Gather ' + 'Compass', 'Gather ' + 'Guide', 'Gather ' + 'Route Guide']
former += ['/' + 'gc' + 'f']
names = subprocess.check_output(['git', 'ls-files', '-co', '--exclude-standard', '-z'], cwd=root).decode().split('\0')
checked = 0
for name in sorted(set(filter(None, names))):
    path = root / name
    if not path.is_file():
        continue
    assert not any(value.casefold() in name.casefold() for value in former), f'Former branding in path: {name}'
    if path.suffix.lower() not in {'.lua', '.md', '.py', '.ps1', '.txt', '.toc', '.yml', '.yaml', '.html', '.svg'}:
        continue
    content = path.read_text(encoding='utf-8-sig')
    assert not any(value.casefold() in content.casefold() for value in former), f'Former branding in {name}'
    for addon in re.findall(r'Interface[\\/]+AddOns[\\/]+([^\\/\s\'"]+)', content):
        assert addon == 'Gatherly', f'Wrong runtime addon path in {name}: {addon}'
    checked += 1
print(f'Branding: Gatherly identity, folder, slash command and asset paths verified in {checked} text files')
