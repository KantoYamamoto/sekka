"""Replay known, frozen, fully validated material. Raw outputs stay private."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess



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
        text_a = subprocess.run(command + ['--text'], capture_output=True)
        text_b = subprocess.run(command + ['--text'], capture_output=True)
        if (text_a.returncode, text_a.stdout, text_a.stderr) != (text_b.returncode, text_b.stdout, text_b.stderr) or text_a.returncode or text_a.stderr:
            raise ValueError('Unstable or failed text process: ' + case['id'])
        (args.output / (case['id'] + '.text')).write_bytes(text_a.stdout)
        results.append({'case': case['id'], 'exit': a.returncode, 'fullProcessBytesEqual': True,
            'stdoutBytes': len(a.stdout), 'stdoutSHA256': sha(a.stdout), 'stderrSHA256': sha(a.stderr),
            'textBytes': len(text_a.stdout), 'textSHA256': sha(text_a.stdout), 'textProcessBytesEqual': True,
            'relationships': len(report['relationships']), 'users': sum(len(r['users']) for r in report['relationships']),
            'unknown': len(report['unknown']), 'switchCounts': {s: report[s]['switches'] for s in ('before', 'after')},
            'inputScopes': {s: report[s] for s in ('before', 'after')}})
        print(case['id'], len(report['relationships']), 'relationships', sum(len(r['users']) for r in report['relationships']), 'written users', flush=True)
    if sha(args.binary.read_bytes()) != binary_sha:
        raise ValueError('Binary changed during replay')
    (args.output / 'execution.json').write_text(json.dumps({'binarySHA256': binary_sha,
        'inputsSHA256': sha(args.inputs.read_bytes()), 'validatedEntries': sum(len(c['files']) for c in cases),
        'runnerSHA256': sha(Path(__file__).read_bytes()),
        'results': results, 'meaning': 'Known-input direct output replay, not independent or unseen benefit'}, indent=2) + '\n')


if __name__ == '__main__':
    main()
