"""Replay the fixed, already-read case with our parser; never execute the target."""
import argparse
import hashlib
import json
import subprocess
import time
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('--binary', type=Path, required=True)
parser.add_argument('--packet', type=Path, required=True)
parser.add_argument('--inputs', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
sha = lambda data: hashlib.sha256(data).hexdigest()
anchors = json.loads((Path(__file__).parent.parent / 'anchors.json').read_text())
manifest_bytes = args.inputs.read_bytes()
assert sha(manifest_bytes) == anchors['inputsManifestSHA256']
item = next(row for row in json.loads(manifest_bytes) if row['id'] == anchors['case'])
for side in ['before', 'after']:
    expected = {entry['path']: entry for entry in item['files'] if entry['side'] == side}
    actual = {str(path.relative_to(args.packet / side)) for path in (args.packet / side).rglob('*') if path.is_file()}
    assert actual == set(expected), (side, 'inventory mismatch')
    for name, entry in expected.items():
        path = args.packet / side / name
        assert not path.is_symlink()
        data = path.read_bytes()
        assert len(data) == entry['bytes'] and sha(data) == entry['sha256']
        assert hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() == entry['blob']

binary = args.binary.resolve()
source = Path(__file__).parent / 'Sources/state-probe/main.swift'
identity = dict(binarySHA256=sha(binary.read_bytes()), sourceSHA256=sha(source.read_bytes()),
                runnerSHA256=sha(Path(__file__).read_bytes()), inputsManifestSHA256=sha(manifest_bytes))
# Private output must be new: a failure cannot leave a previous success receipt.
args.output.mkdir(parents=True, exist_ok=False)
formats = {}
for name, flags in [('json', []), ('text', ['--text'])]:
    runs, seconds = [], []
    for _ in range(2):
        start = time.monotonic()
        runs.append(subprocess.run([str(binary), str(args.packet / 'before/GRDB'),
                                    str(args.packet / 'after/GRDB')] + flags, capture_output=True))
        seconds.append(time.monotonic() - start)
    first, second = runs
    assert (first.returncode, first.stdout, first.stderr) == (second.returncode, second.stdout, second.stderr)
    assert first.returncode == 0 and not first.stderr, (name, first.returncode, first.stderr)
    (args.output / ('report.' + name)).write_bytes(first.stdout)
    formats[name] = dict(stdoutSHA256=sha(first.stdout), stderrSHA256=sha(first.stderr),
                         bytes=len(first.stdout), lines=len(first.stdout.splitlines()),
                         fullProcessBytesEqual=True, seconds=seconds)
assert identity['binarySHA256'] == sha(binary.read_bytes())
assert identity['sourceSHA256'] == sha(source.read_bytes())
report = json.loads((args.output / 'report.json').read_bytes())
receipt = dict(identity, case=anchors['case'], scope='Known-source expression diagnostic, not unseen utility',
               files=[report['beforeFiles'], report['afterFiles']], relationships=len(report['relationships']),
               beforeInputSHA256=report['beforeInputSHA256'], afterInputSHA256=report['afterInputSHA256'],
               formats=formats)
(args.output / 'execution.json').write_text(json.dumps(receipt, indent=2) + '\n')
print(json.dumps(receipt, indent=2))
