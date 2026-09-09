#!/usr/bin/env python3
"""Fetch only fixed public blobs with GET; never execute or modify upstream code."""
import argparse
import base64
import hashlib
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
manifest = json.loads(Path(__file__).with_name('inputs.json').read_text())
# Require a fresh destination: stale files must not change the analysis scope.
args.output.mkdir(parents=True, exist_ok=False)
for case in manifest:
    for entry in case['files']:
        path = Path(entry['path'])
        if path.is_absolute() or '..' in path.parts or entry['side'] not in ('before', 'after'):
            raise ValueError('Invalid manifest path')
        endpoint = f"repos/{case['repository']}/git/blobs/{entry['blob']}"
        payload = json.loads(subprocess.check_output(['gh', 'api', '--method', 'GET', endpoint]))
        if payload.get('encoding') != 'base64':
            raise ValueError('Expected base64 blob')
        content = base64.b64decode(payload['content'])
        blob = hashlib.sha1(b'blob ' + str(len(content)).encode() + b'\0' + content).hexdigest()
        if (blob != entry['blob'] or len(content) != entry['bytes']
                or hashlib.sha256(content).hexdigest() != entry['sha256']):
            raise ValueError(f"Blob verification failed: {path}")
        target = args.output / case['id'] / entry['side'] / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(content)
    print(f"{case['id']}: verified {len(case['files'])} blobs", flush=True)
print('Complete. Selected files only; no target code was executed.')
