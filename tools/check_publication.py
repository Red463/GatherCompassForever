"""Check public documentation, image assets and the staged/tracked file manifest."""
from pathlib import Path
import re
import subprocess
from urllib.parse import unquote, urlparse

root = Path(__file__).resolve().parents[1]
readme = (root / 'README.md').read_text(encoding='utf-8')
license_text = (root / 'LICENSE').read_text(encoding='utf-8')
assert license_text.startswith('MIT License\n')
assert 'Copyright (c) 2026 Tom' in license_text
assert 'Bundled third-party libraries retain' in readme
assert 'in-game screenshots supplied by the author' in readme and '**v0.18.6**' in readme
screenshots = {'welcome', 'routes', 'route-heatmap', 'node-codex', 'marker-filters',
               'preferences', 'guide-arrow', 'route-controls'}
readme_images = set(re.findall(r'docs/images/([^/)]+)\.png', readme))
assert readme_images == screenshots | {'logo'}, 'README must use only supplied screenshots and branding'

links = re.findall(r'!?\[[^\]]*\]\(([^)]+)\)', readme)
links += re.findall(r'<img[^>]+src="([^"]+)"', readme)
for link in links:
    parsed = urlparse(link)
    if parsed.scheme or link.startswith('#'):
        continue
    target = (root / unquote(parsed.path)).resolve()
    assert target.is_relative_to(root), f'Link escapes repository: {link}'
    assert target.is_file(), f'Broken README link: {link}'
for path in (root / 'docs/images').glob('*.png'):
    assert path.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'), f'Invalid image: {path.name}'

if (root / '.git').exists():
    result = subprocess.run(['git', 'ls-files', '-z'], cwd=root, check=True, capture_output=True)
    files = [name for name in result.stdout.decode().split('\0') if name]
    assert files, 'No staged/tracked publication files'
    private = ('.test-deps/', '.superpowers/', '.agents/', '.codex/', 'dist/',
               'docs/superpowers/', 'docs/previews/', 'WTF/', 'SavedVariables/',
               'docs/classic-ui-progress.md', 'docs/classic-ui-design.md',
               'docs/classic-ui-mockup.html', 'docs/difficulty-colour-research.md')
    tokens = re.compile(r'(?:gh[pousr]_[A-Za-z0-9]{30,}|github_pat_[A-Za-z0-9_]{30,}|AKIA[A-Z0-9]{16})')
    machine_path = re.compile(r'[A-Za-z]:[/\\]Users[/\\]')
    for name in files:
        assert not name.startswith(private), f'Local-only file staged: {name}'
        path = root / name
        if path.suffix.lower() in {'.lua', '.py', '.md', '.yml', '.yaml', '.txt', '.toc'}:
            content = path.read_text(encoding='utf-8')
            assert not tokens.search(content), f'Credential-like value in {name}'
            assert not machine_path.search(content), f'Personal machine path in {name}'
    print(f'Public file manifest: {len(files)} files; local-only paths and credential-like values excluded')
print(f'Publication: MIT license, README links and {len(list((root / "docs/images").glob("*.png")))} PNG examples verified')
