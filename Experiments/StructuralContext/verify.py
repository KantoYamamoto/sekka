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
    existing = 'struct Menu { func open() { Service(); Welcome() } }'
    for side in [before, after]:
        (side / 'Old.swift').write_text(existing)
        (side / '.ignored').mkdir()
        (side / '.ignored' / 'broken.swift').write_text('struct {')
        if hasattr(os, 'chflags') and hasattr(stat, 'UF_HIDDEN'):
            os.chflags(side / 'Old.swift', stat.UF_HIDDEN)
    (after / 'New.swift').write_text('struct Sheet { var body: View { Welcome(); Service() } }')
    report = run(before, after)
    assert report['beforeFileCount'] == 1 and report['afterFileCount'] == 2
    context = report['contexts'][0]
    assert len(report['contexts']) == 1
    assert context['after']['file'] == 'New.swift'
    assert context['sharedCalls'][0]['before']['site']['declaration'] == 'Menu.open()'
    results.append({'case': 'unchanged-context-hidden-metadata', 'report': report})
    assert run(after, after)['contexts'] == []
    text = subprocess.check_output([binary, str(before), str(after), '--text']).decode()
    assert '┌ after New.swift:1' in text and 'before Old.swift:1' in text
    assert '呼び出し先は未解決' in text
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
    manifest = json.loads(Path(__file__).with_name('holdout-inputs.json').read_text())
    for case in manifest:
        root = args.oss_input / case['id']
        for side in ['before', 'after']:
            entries = [f for f in case['files'] if f['side'] == side]
            assert sorted(str(p.relative_to(root / side)) for p in (root / side).rglob('*.swift')) == sorted(f['path'] for f in entries)
            for entry in entries:
                assert hashlib.sha256((root / side / entry['path']).read_bytes()).hexdigest() == entry['sha256']
        report = run(root / 'before', root / 'after')
        for side in ['before', 'after']:
            assert report[side + 'FileCount'] == sum(f['side'] == side for f in case['files'])
        if case['id'] == 'wordpress-ios-25624':
            context = next(c for c in report['contexts'] if c['after']['declaration'] == 'StockPhotosPickerSheet.body')
            assert context['after']['line'] == 9
            neighbor = context['sharedCalls'][0]
            assert neighbor['before']['site']['line'] == 19
            assert neighbor['after'][0]['site']['line'] == 19
            assert neighbor['after'][0]['spellings'] == neighbor['before']['spellings']
            assert neighbor['before']['spellings'] == ['DefaultStockPhotosService(api:)', 'StockPhotosDataSource(service:)', 'StockPhotosWelcomeView()']
        else:
            context = next(c for c in report['contexts'] if c['after']['declaration'] == 'AsyncPipelineTask.decode(_:decoder:_:)')
            group = next(g for g in report['selectorGroups'] if g['selector'] == context['sameSelector'])
            assert context['before'][0]['line'] == 44 and context['after']['line'] == 44
            assert [c['site']['line'] for c in group['before']] == [57, 36]
            assert [c['site']['line'] for c in group['after']] == [57, 36]
            assert len(group['declarationCandidates']) == 1
        # Calls can have unresolved receivers even when one declared selector matches.
        results.append({'case': case['id'], 'report': report})

args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'meaning': 'Syntax candidates, not design judgement or review benefit.', 'results': results}, indent=2) + '\n')
print('PASS: deterministic context, file counts/locations, hidden metadata, malformed input and symlink rejection')
