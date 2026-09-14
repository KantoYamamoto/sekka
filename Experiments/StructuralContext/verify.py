"""Check experimental input boundaries and fixed source locations, not design quality."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import stat
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--binary', type=Path, required=True)
parser.add_argument('--output', type=Path, required=True)
parser.add_argument('--oss-input', type=Path)
parser.add_argument('--text-output', type=Path)
args = parser.parse_args()
binary = str(args.binary.resolve())
results = []


def run(before, after):
    command = [binary, str(before), str(after)]
    first = subprocess.check_output(command)
    assert first == subprocess.check_output(command), 'Unstable output'
    return json.loads(first)


with tempfile.TemporaryDirectory(prefix='sekka-context-') as directory:
    root = Path(directory) / '.parent'
    before, after = root / 'before', root / '.after'
    before.mkdir(parents=True); after.mkdir()
    existing = 'struct Menu { func open() { clock.now }; func ping() { clock.now } }'
    for side in [before, after]:
        (side / 'Old.swift').write_text(existing)
        (side / '.ignored').mkdir()
        (side / '.ignored' / 'broken.swift').write_text('struct {')
        if hasattr(os, 'chflags') and hasattr(stat, 'UF_HIDDEN'):
            os.chflags(side / 'Old.swift', stat.UF_HIDDEN)
    (after / 'Old.swift').write_text(existing.replace('func open() { clock.now }', 'func open() { Instant() }'))
    report = run(before, after)
    assert report['beforeFileCount'] == 1 and report['afterFileCount'] == 1
    context = report['contexts'][0]
    assert len(report['contexts']) == 1
    assert context['spelling'] == 'clock.now'
    assert context['reductions'][0]['before']['count'] == 1
    assert context['retained'][0]['after']['declaration']['declaration'] == 'Menu.ping()'
    results.append({'case': 'unchanged-context-hidden-metadata', 'report': report})
    assert run(after, after)['contexts'] == []
    text = subprocess.check_output([binary, str(before), str(after), '--text']).decode()
    assert '┌ clock.now' in text and 'before Old.swift:1' in text
    assert '参照先は未解決' in text
    text_samples = ['Case: unchanged-context-hidden-metadata\n' + text]
    (after / 'Broken.swift').write_text('struct {')
    failed = subprocess.run([binary, str(before), str(after)], capture_output=True)
    assert failed.returncode == 2 and failed.stdout == b''
    (after / 'Broken.swift').unlink()
    (after / 'link.swift').symlink_to(root / 'missing.swift')
    failed = subprocess.run([binary, str(before), str(after)], capture_output=True)
    assert failed.returncode == 2 and failed.stdout == b''
    (after / 'link.swift').unlink()
    link = root / 'linked'; link.symlink_to(after, target_is_directory=True)
    failed = subprocess.run([binary, str(before), str(link)], capture_output=True)
    assert failed.returncode == 2 and failed.stdout == b''

if args.oss_input:
    manifest = json.loads(Path(__file__).with_name('retrieval-inputs.json').read_text())
    for case in manifest:
        root = args.oss_input / case['id']
        for side in ['before', 'after']:
            entries = [f for f in case['files'] if f['side'] == side]
            assert sorted(str(p.relative_to(root / side)) for p in (root / side).rglob('*') if p.is_file()) == sorted(f['path'] for f in entries)
            for entry in entries:
                assert hashlib.sha256((root / side / entry['path']).read_bytes()).hexdigest() == entry['sha256']
        report = run(root / 'before', root / 'after')
        for side in ['before', 'after']:
            assert report[side + 'FileCount'] == sum(f['side'] == side and f['path'].endswith('.swift') for f in case['files'])
        if case['id'] == 'alamofire-4051':
            assert len(report['contexts']) == 1
            context = report['contexts'][0]
            assert context['spelling'] == 'ProcessInfo.processInfo.systemUptime'
            assert sum(c['before']['count'] for c in context['reductions']) == 6
            assert sum(c['after']['count'] for c in context['reductions']) == 0
            assert len(context['retained']) == 1
            retained = context['retained'][0]
            assert retained['bodyChanged'] is False
            assert retained['after']['declaration']['file'] == 'Source/Core/WebSocketRequest.swift'
            assert [s['line'] for s in retained['after']['sites']] == [286, 296]
        else:
            assert report['contexts'] == []  # No reduction anchor; not a design verdict.
        results.append({'case': case['id'], 'report': report})
        if args.text_output:
            text_samples.append('Case: ' + case['id'] + '\n' + subprocess.check_output([binary, str(root / 'before'), str(root / 'after'), '--text']).decode())

args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'meaning': 'Syntax candidates, not design judgement or review benefit.', 'results': results}, indent=2) + '\n')
if args.text_output:
    args.text_output.parent.mkdir(parents=True, exist_ok=True)
    args.text_output.write_text('\n'.join(text_samples))
print('PASS: deterministic context, file counts/locations, hidden metadata, malformed input and symlink rejection')
