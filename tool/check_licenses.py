"""Offline guard: every locked Dart package must have reviewed license evidence."""
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[1]
lock = (root / 'pubspec.lock').read_text()
packages = {}
name = None
for line in lock.splitlines():
    match = re.match(r'^  ([a-zA-Z0-9_]+):$', line)
    if match:
        name = match[1]
    match = re.match(r'^    version: "([^"]+)"$', line)
    if match and name:
        packages[name] = match[1]
reviewed = json.loads((root / 'docs/licenses/inventory.json').read_text())
assert packages == {p['name']: p['version'] for p in reviewed}, 'Unreviewed package/version'
for item in reviewed:
    assert item['license'] in {'BSD-3-Clause', 'MIT', 'Apache-2.0'} or (
        item['name'] == 'sky_engine' and item['license'] ==
        'BSD-3-Clause + bundled engine notices'), item
    assert item['source'].startswith('https://'), item
    assert (root / item['notice']).read_text().strip(), item
print(f'PASS: {len(reviewed)} locked packages have reviewed license records')
