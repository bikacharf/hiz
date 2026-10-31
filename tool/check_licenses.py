"""Offline guard: every locked Dart package must have reviewed license evidence."""
import hashlib
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
    notice = (root / item['notice']).read_bytes()
    assert notice.strip(), item
    # Git may materialize text files with CRLF on Windows. The inventory hashes
    # the canonical LF representation stored in the repository, so normalize
    # only line endings before comparing the reviewed notice hash.
    canonical_notice = notice.replace(b'\r\n', b'\n')
    assert (
        hashlib.sha256(canonical_notice).hexdigest() == item['notice_sha256']
    ), item
models = json.loads((root / 'docs/models/inventory.json').read_text())
for item in models:
    assert item['license'] in {'BSD-3-Clause', 'MIT', 'Apache-2.0'}, item
    assert item['source'].startswith('https://'), item
    artifact = root / item['artifact']
    assert artifact.is_file() and artifact.stat().st_size == item['bytes'], item
    assert hashlib.sha256(artifact.read_bytes()).hexdigest() == item['sha256'], item
    notice = (root / item['notice']).read_bytes().replace(b'\r\n', b'\n')
    assert notice.strip(), item
    assert hashlib.sha256(notice).hexdigest() == item['notice_sha256'], item

print(
    f'PASS: {len(reviewed)} locked packages and {len(models)} model artifact '
    'have reviewed license records'
)
