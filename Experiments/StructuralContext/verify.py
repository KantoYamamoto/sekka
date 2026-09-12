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
    existing = 'class Host { func media(_ value: Request) {} }\nclass Old: Host { override func media(_ value: Request) { show(value) } }'
    for side in [before, after]:
        (side / 'Old.swift').write_text(existing)
        (side / '.ignored').mkdir()
        (side / '.ignored' / 'broken.swift').write_text('struct {')
        if hasattr(os, 'chflags') and hasattr(stat, 'UF_HIDDEN'):
            os.chflags(side / 'Old.swift', stat.UF_HIDDEN)
    (after / 'New.swift').write_text('class New: Host {}')
    report = run(before, after)
    assert report['beforeFileCount'] == 1 and report['afterFileCount'] == 2
    family = report['families'][0]
    assert len(report['families']) == 1
    assert family['addedType']['location']['file'] == 'New.swift'
    assert family['slots'][0]['peers'][0]['after']['exactSpelling'][0]['location']['line'] == 2
    results.append({'case': 'unchanged-context-hidden-metadata', 'report': report})
    assert run(after, after)['families'] == []
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
    manifest = json.loads(Path(__file__).with_name('inputs.json').read_text())
    for case in manifest:
        if case['id'] == 'wordpress-25855':
            continue  # Retrospective evidence, not an additional test case.
        root = args.oss_input / case['id']
        for side in ['before', 'after']:
            entries = [f for f in case['files'] if f['side'] == side]
            assert sorted(str(p.relative_to(root / side)) for p in (root / side).rglob('*.swift')) == sorted(f['path'] for f in entries)
            for entry in entries:
                assert hashlib.sha256((root / side / entry['path']).read_bytes()).hexdigest() == entry['sha256']
        report = run(root / 'before', root / 'after')
        for side in ['before', 'after']:
            assert report[side + 'FileCount'] == sum(f['side'] == side for f in case['files'])
        if case['id'] == 'wordpress-25208':
            assert len(report['families']) == 1
            slots = report['families'][0]['slots']
            media = next(s for s in slots if 'didRequestMediaFromSiteMediaLibrary:' in s['parent']['after']['exactSpelling'][0]['selector'])
            assert media['parent']['after']['exactSpelling'][0]['location']['line'] == 145
            assert media['peers'][0]['after']['exactSpelling'][0]['location']['line'] == 262
            media_before = media['parent']['before']
            assert (media_before['exactSpelling'] + media_before['otherSpellings'])[0]['body'] == 'empty'
            history = next(s for s in slots if 'didUpdateHistoryState:' in s['parent']['after']['exactSpelling'][0]['selector'])
            assert history['added']['after']['otherSpellings'][0]['location']['line'] == 67
            assert history['parent']['before']['exactSpelling'][0]['body'] == 'statements'
            assert history['parent']['before']['exactSpelling'][0]['location']['line'] == 119
            assert history['parent']['after']['exactSpelling'][0]['body'] == 'empty'
            assert history['peers'][0]['before']['exactSpelling'] == []
            assert history['peers'][0]['before']['otherSpellings'] == []
        else:
            assert report['families'] == []
        results.append({'case': case['id'], 'report': report})

args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'meaning': 'Syntax candidates, not design judgement or review benefit.', 'results': results}, indent=2) + '\n')
print('PASS: deterministic context, file counts/locations, hidden metadata, malformed input and symlink rejection')
