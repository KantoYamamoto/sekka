"""Replay known, frozen, fully validated material. Raw outputs stay private."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

from analyze import analyze


def sha(data):
    return hashlib.sha256(data).hexdigest()


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--packet', type=Path, required=True)
    p.add_argument('--inputs', type=Path, required=True)
    p.add_argument('--binary', type=Path, required=True)
    p.add_argument('--checks', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    cases = json.loads(args.inputs.read_text())
    checks = json.loads(args.checks.read_text())
    binary_sha = sha(args.binary.read_bytes())
    if binary_sha != checks['binarySHA256']:
        raise ValueError('Binary differs from control run')
    # Validate the complete frozen packet, not just files that happen to yield relationships.
    for case in cases:
        for side in ('before', 'after'):
            folder = args.packet / case['id'] / side
            paths = list(folder.rglob('*'))
            if folder.is_symlink() or any(p.is_symlink() for p in paths):
                raise ValueError('Symlink input')
            expected = {f['path']: f for f in case['files'] if f['side'] == side}
            if {str(p.relative_to(folder)) for p in paths if p.is_file()} != set(expected):
                raise ValueError('Frozen input inventory differs')
            for name, entry in expected.items():
                data = (folder / name).read_bytes()
                blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
                if len(data) != entry['bytes'] or sha(data) != entry['sha256'] or blob != entry['blob']:
                    raise ValueError('Frozen input bytes differ')
    args.output.mkdir(parents=True, exist_ok=False)
    results = []
    for case in cases:
        command = [str(args.binary.resolve()), str(args.packet / case['id'] / 'before' / case['prefix']),
                   str(args.packet / case['id'] / 'after' / case['prefix'])]
        a = subprocess.run(command, capture_output=True)
        b = subprocess.run(command, capture_output=True)
        if (a.returncode, a.stdout, a.stderr) != (b.returncode, b.stdout, b.stderr):
            raise ValueError('Unstable complete process bytes: ' + case['id'])
        (args.output / (case['id'] + '.stdout')).write_bytes(a.stdout)
        (args.output / (case['id'] + '.stderr')).write_bytes(a.stderr)
        if a.returncode != 0 or a.stderr:
            raise ValueError('Input failed, not zero relationships: ' + case['id'])
        report = json.loads(a.stdout)
        first = analyze(report); second = analyze(report)
        out = json.dumps(first, ensure_ascii=False, indent=2).encode() + b'\n'
        if out != json.dumps(second, ensure_ascii=False, indent=2).encode() + b'\n':
            raise ValueError('Unstable analyzer bytes')
        (args.output / (case['id'] + '.relationships.json')).write_bytes(out)
        results.append({'case': case['id'], 'exit': a.returncode, 'fullProcessBytesEqual': True,
            'stdoutBytes': len(a.stdout), 'stdoutSHA256': sha(a.stdout), 'stderrSHA256': sha(a.stderr),
            'relationshipBytesEqual': True, 'relationshipSHA256': sha(out),
            'relationships': len(first['relationships']), 'users': len(first['users']),
            'unknown': len(first['unknown']), 'switchCounts': first['switchCounts']})
        print(case['id'], len(first['relationships']), 'relationships', len(first['users']), 'written users', flush=True)
    if sha(args.binary.read_bytes()) != binary_sha:
        raise ValueError('Binary changed during replay')
    (args.output / 'execution.json').write_text(json.dumps({'source': checks['source'], 'binarySHA256': binary_sha,
        'inputsSHA256': sha(args.inputs.read_bytes()), 'validatedEntries': sum(len(c['files']) for c in cases),
        'runnerSHA256': sha(Path(__file__).read_bytes()),
        'analyzerSHA256': sha(Path(__file__).with_name('analyze.py').read_bytes()),
        'results': results, 'meaning': 'Known-input diagnostic, not independent or unseen benefit'}, indent=2) + '\n')


if __name__ == '__main__':
    main()
