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
    existing = 'struct Logger { func record(_ event: String) { send(event) } }\nstruct Screen { let logger: Logger; func open(_ event: String) { logger.record(event) } }'
    for side in [before, after]:
        (side / 'Old.swift').write_text(existing)
        (side / '.ignored').mkdir()
        (side / '.ignored' / 'broken.swift').write_text('struct {')
        if hasattr(os, 'chflags') and hasattr(stat, 'UF_HIDDEN'):
            os.chflags(side / 'Old.swift', stat.UF_HIDDEN)
    (after / 'Old.swift').write_text(existing.replace('logger.record(event) }', 'logger.record(event); analytics.record(event) }'))
    report = run(before, after)
    assert report['beforeFileCount'] == 1 and report['afterFileCount'] == 1
    context = report['contexts'][0]
    assert len(report['contexts']) == 1
    assert context['after']['declaration'] == 'Logger.record(_:)'
    assert context['fileUnchanged'] is False
    assert context['entries'][0]['writtenType'] == 'Logger'
    assert context['entries'][0]['sharedArgumentSpellings'] == ['event']
    results.append({'case': 'unchanged-context-hidden-metadata', 'report': report})
    assert run(after, after)['contexts'] == []
    text = subprocess.check_output([binary, str(before), str(after), '--text']).decode()
    assert '┌ 未変更の関数候補: Old.swift:1' in text and 'before Old.swift:1' in text
    assert '呼び出し先は未解決' in text
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

# Already-known fact controls; these do not measure review benefit.
fixture_path = Path(__file__).resolve().parents[2] / 'Fixtures/structural-reconsideration/cases.json'
expected_entries = {'dispatch-spread': 3, 'dispatch-growth': 2, 'single-site': 1,
                    'dispatch-separate-policy': 3, 'dispatch-contained': 0,
                    'consent-separated': 0, 'natural-model': 0}
fixture_reports = {}
for case in json.loads(fixture_path.read_text()):
    with tempfile.TemporaryDirectory(prefix='sekka-known-context-') as directory:
        root = Path(directory)
        for side in ['before', 'after']:
            (root / side).mkdir()
            for name, source in case[side].items():
                path = root / side / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(source)
        report = run(root / 'before', root / 'after')
        fixture_reports[case['name']] = report
        expected = expected_entries[case['name']]
        assert len(report['contexts']) == (1 if expected else 0), case['name']
        if expected:
            target = report['contexts'][0]
            assert target['after']['file'] == 'Logger.swift'
            assert target['after']['line'] == 2
            assert target['after']['declaration'] == 'Logger.record(_:)'
            assert target['fileUnchanged'] is True
            assert len(target['entries']) == expected
            for entry in target['entries']:
                assert entry['beforeExistingCall']['line'] == 4
                assert entry['afterExistingCall']['line'] == 5
                assert entry['newOrChangedCall']['line'] == 6
                assert entry['beforeReceiver']['line'] == entry['afterReceiver']['line'] == 2
                assert entry['sharedArgumentSpellings'] == ['event']
        results.append({'case': case['name'], 'report': report})
        text_samples.append('Case: ' + case['name'] + '\n' + subprocess.check_output(
            [binary, str(root / 'before'), str(root / 'after'), '--text']).decode())
assert fixture_reports['dispatch-spread'] == fixture_reports['dispatch-separate-policy']

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
        # These previously read OSS changes have no eligible path in this query.
        # Record rejection reasons; zero is not evidence about their design.
        assert report['contexts'] == [], case['id']
        results.append({'case': case['id'], 'report': report})
        if args.text_output:
            text_samples.append('Case: ' + case['id'] + '\n' + subprocess.check_output([binary, str(root / 'before'), str(root / 'after'), '--text']).decode())

args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'meaning': 'Syntax candidates, not design judgement or review benefit.', 'results': results}, indent=2) + '\n')
if args.text_output:
    args.text_output.parent.mkdir(parents=True, exist_ok=True)
    args.text_output.write_text('\n'.join(text_samples))
print('PASS: deterministic context, file counts/locations, hidden metadata, malformed input and symlink rejection')
