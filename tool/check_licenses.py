"""Verify locked versions and reviewed license hashes without network access."""
import hashlib
import json
import pathlib
import re
from urllib.parse import unquote, urlparse

root = pathlib.Path(__file__).resolve().parents[1]
lock = (root / 'pubspec.lock').read_text()
inventory = {}
for line in (root / 'docs/DEPENDENCIES.md').read_text().splitlines():
    cells = [cell.strip() for cell in line.split('|')]
    if len(cells) == 7 and re.fullmatch(r'[a-f0-9]{64}', cells[5]):
        inventory[cells[1]] = (cells[2], cells[5])
packages = {}
for block in re.split(r'^  (?=\w+:\s*$)', lock, flags=re.M)[1:]:
    version = re.search(r'^    version: "([^"]+)"', block, re.M)
    if version:
        packages[block.split(':', 1)[0]] = version.group(1)
assert packages, 'No lockfile packages parsed'
assert set(packages) == set(inventory), 'Dependency inventory drift'
config = json.loads((root / '.dart_tool/package_config.json').read_text())
resolved = {p['name']: p for p in config['packages'] if p['name'] != 'hiz'}
assert set(resolved) == set(packages), 'Resolved package inventory drift'
for name, version in packages.items():
    reviewed_version, reviewed_hash = inventory[name]
    assert version == reviewed_version, f'Unreviewed version: {name} {version}'
    uri = resolved[name]['rootUri']
    path = (pathlib.Path(unquote(urlparse(uri).path)) if uri.startswith('file:')
            else root / '.dart_tool' / uri)
    license_path = path / 'LICENSE'
    if name == 'flutter_test':
        license_path = path.parents[1] / 'LICENSE'
    assert license_path.is_file(), f'Missing LICENSE: {name}'
    digest = hashlib.sha256(license_path.read_bytes()).hexdigest()
    assert digest == reviewed_hash, f'License changed: {name}'
print(f'PASS: {len(packages)} pinned dependencies and license hashes verified')
