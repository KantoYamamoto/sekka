"""Replay fixed syntax inputs. This measures reach, not review benefit."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--binary', type=Path, required=True)
parser.add_argument('--input', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
args = parser.parse_args()
manifest = json.loads(Path(__file__).with_name('inputs.json').read_text())
binary = args.binary.resolve()
# Validate every selected source before any parsing. Failures are not zero candidates.
for case in manifest:
    for side in ['before', 'after']:
        root = args.input / case['id'] / side
        expected = {f['path']: f for f in case['files'] if f['side'] == side}
        actual = {str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()}
        if actual != set(expected):
            raise ValueError('Input inventory differs: ' + case['id'] + '/' + side)
        for name, entry in expected.items():
            path = root / name
            if path.is_symlink() or hashlib.sha256(path.read_bytes()).hexdigest() != entry['sha256']:
                raise ValueError('Input bytes differ: ' + str(path))
args.output.mkdir(parents=True, exist_ok=False)
results = []
for case in manifest:
    command = [str(binary), str(args.input / case['id'] / 'before' / case['prefix']),
               str(args.input / case['id'] / 'after' / case['prefix'])]
    first = subprocess.run(command, capture_output=True)
    second = subprocess.run(command, capture_output=True)
    if (first.returncode, first.stdout, first.stderr) != (second.returncode, second.stdout, second.stderr):
        raise ValueError('Unstable result: ' + case['id'])
    record = {'case': case['id'], 'returnCode': first.returncode, 'sourcePrefix': case['prefix']}
    if first.returncode == 0:
        record['report'] = json.loads(first.stdout)
        (args.output / (case['id'] + '.json')).write_bytes(first.stdout)
        (args.output / (case['id'] + '.text')).write_bytes(subprocess.check_output(command + ['--text']))
    else:
        record['error'] = first.stderr.decode()
        if first.stdout:
            raise ValueError('Failure produced partial output: ' + case['id'])
    results.append(record)
    print(case['id'] + ': ' + ('parsed' if first.returncode == 0 else 'failed; not a zero-candidate result'), flush=True)
(args.output / 'results.json').write_text(json.dumps({
    'binarySHA256': hashlib.sha256(binary.read_bytes()).hexdigest(),
    'meaning': 'Fixed production source scope only. Facts and navigation candidates, not design verdict or review benefit.',
    'results': results,
}, indent=2) + '\n')
