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
    assert context['entries'][0]['existingCall']['evidence']['writtenType'] == 'Logger'
    assert context['entries'][0]['existingCall']['evidence']['sharedArgumentSpellings'] == ['event']
    results.append({'case': 'unchanged-context-hidden-metadata', 'report': report})
    assert run(after, after)['contexts'] == []
    text = subprocess.check_output([binary, str(before), str(after), '--text']).decode()
    assert '┌ 未変更の宣言候補 [function]: Old.swift:1' in text and 'before Old.swift:1' in text
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

# Parse both conditional accessor spellings; do not compile the target or select a branch.
with tempfile.TemporaryDirectory(prefix='sekka-accessors-') as directory:
    root = Path(directory)
    source = """struct Buffer {
  var value: Int
  subscript(i: Int) -> Int {
#if compiler(>=6.4)
    borrow { value }
    mutate { &value }
#else
    get { value }
    set { value = newValue }
#endif
  }
}
"""
    for side, annotation in [('before', 'Int'), ('after', 'Buffer')]:
        folder = root / side
        folder.mkdir()
        (folder / 'Buffer.swift').write_text(source)
        (folder / 'Store.swift').write_text('struct Store { var value: ' + annotation + ' }\n')
    report = run(root / 'before', root / 'after')
    assert len(report['contexts']) == 1
    target = report['contexts'][0]
    assert target['after']['file'] == 'Buffer.swift' and target['after']['line'] == 1
    assert target['after']['endLine'] == 12 and target['fileUnchanged']
    results.append({'case': 'conditional-borrow-mutate-accessors', 'report': report})
    text_samples.append('Case: conditional-borrow-mutate-accessors\n' + subprocess.check_output(
        [binary, str(root / 'before'), str(root / 'after'), '--text']).decode())
    (root / 'after' / 'Broken.swift').write_text('struct {')
    failed = subprocess.run([binary, str(root / 'before'), str(root / 'after')], capture_output=True)
    assert failed.returncode == 2 and failed.stdout == b''

# A type-annotation entry shares the same declaration list and text renderer.
with tempfile.TemporaryDirectory(prefix='sekka-type-context-') as directory:
    root = Path(directory)
    for side, annotation in [('before', 'Int'), ('after', 'Buffer<Int>')]:
        folder = root / side
        folder.mkdir()
        (folder / 'Buffer.swift').write_text('struct Buffer<Element>: Sendable {}\n')
        (folder / 'Store.swift').write_text('struct Store { var value: ' + annotation + ' }\n')
    report = run(root / 'before', root / 'after')
    target = report['contexts'][0]
    assert len(report['contexts']) == 1 and target['kind'] == 'struct'
    assert target['after']['file'] == 'Buffer.swift' and target['fileUnchanged']
    entry = target['entries'][0]['changedType']['evidence']
    assert entry['reference']['written'] == 'Buffer' and entry['matchingDeclarations'] == 1
    text = subprocess.check_output([binary, str(root / 'before'), str(root / 'after'), '--text']).decode()
    assert '型注釈の入口' in text and '照合した末尾名: Buffer' in text
    results.append({'case': 'type-annotation-context', 'report': report})
    text_samples.append('Case: type-annotation-context\n' + text)

# Signature changes cannot establish an old caller identity; show a written-label search instead.
with tempfile.TemporaryDirectory(prefix='sekka-member-spelling-') as directory:
    root = Path(directory)
    helper = 'extension Buffer where Element: P { func prune(from index: Int, where test: (Int) -> Bool) {} }\nextension Buffer where Element: P { func other() {} }'
    for side, result_type, result in [('before', 'Bool', 'true'), ('after', 'Int', '0')]:
        folder = root / side; folder.mkdir()
        (folder / 'Helper.swift').write_text(helper)
        (folder / 'Caller.swift').write_text('extension Worker { func generate() -> ' + result_type + ' { defer { target.prune(from: 0, where: { $0 == 0 }) }; return ' + result + ' } }')
    report = run(root / 'before', root / 'after')
    assert len(report['contexts']) == 1
    target = report['contexts'][0]
    assert target['after']['declaration'] == 'extension Buffer.prune(from:where:)' and target['fileUnchanged']
    entry = target['entries'][0]['memberSpelling']['evidence']
    assert entry['callerEvidence'] == 'no-unique-old-indexed-correspondence' and 'beforeCaller' not in entry
    assert entry['call']['selector'] == 'prune(from:where:)' and entry['call']['receiverSpelling'] == 'target'
    assert entry['matchingIndexedDeclarations'] == entry['eligibleOccurrences'] == 1
    text = subprocess.check_output([binary, str(root / 'before'), str(root / 'after'), '--text']).decode()
    assert '一意な旧索引対応は未確認' in text and '同一記載ラベル列の索引内宣言 1件' in text
    results.append({'case': 'member-spelling-unknown-caller', 'report': report})
    text_samples.append('Case: member-spelling-unknown-caller\n' + text)

# Conditional paths must remain beside the written relation, without evaluating activation.
with tempfile.TemporaryDirectory(prefix='sekka-written-conditions-') as directory:
    root = Path(directory)
    for side in ['before', 'after']:
        folder = root / side; folder.mkdir()
        (folder / 'Helper.swift').write_text('extension Helper { func clean(_ value: Int) {} }')
        (folder / 'Caller.swift').write_text('' if side == 'before' else '''#if OUTER
func run() {
#if false
  helper.clean(0)
#else
  helper.clean(0)
#endif
  helper.clean(0)
}
#endif
''')
    report = run(root / 'before', root / 'after')
    assert len(report['contexts']) == 1
    entries = [e['memberSpelling']['evidence'] for e in report['contexts'][0]['entries']]
    assert len(entries) == 3 and all(e['eligibleOccurrences'] == 1 for e in entries)
    paths = [e['call']['writtenConditions'] for e in entries]
    assert [len(p) for p in paths] == [2, 2, 1]
    assert paths[0][1]['selected']['condition'] == 'false'
    assert paths[1][1]['selected']['keyword'] == '#else'
    assert paths[1][1]['preceding'][0]['condition'] == 'false'
    assert paths[0][1]['selected']['site']['line'] == 3
    text = subprocess.check_output([binary, str(root / 'before'), str(root / 'after'), '--text']).decode()
    assert '#if false [Caller.swift:3]' in text and '有効節未判定' in text
    results.append({'case': 'written-conditional-context', 'report': report})
    text_samples.append('Case: written-conditional-context\n' + text)

# Written result names relate existing producers, not resolved constructors/callees.
with tempfile.TemporaryDirectory(prefix='sekka-result-spelling-') as directory:
    root = Path(directory)
    helper = '''struct Receipt {}
func prior() -> Receipt {
#if OLD
  return Receipt(value: 1)
#else
  return Receipt(value: 9)
#endif
}
'''
    for side in ['before', 'after']:
        folder = root / side; folder.mkdir()
        (folder / 'Helper.swift').write_text(helper)
        (folder / 'Caller.swift').write_text('' if side == 'before' else '''func fresh() -> (Receipt, Int) {
#if false
  return (Receipt(value: 2), 0)
#else
  return (Receipt(value: 3), 0)
#endif
}
''')
    report = run(root / 'before', root / 'after')
    assert len(report['contexts']) == 1 and report['contexts'][0]['after']['declaration'] == 'prior()'
    entries = [e['resultSpelling']['evidence'] for e in report['contexts'][0]['entries']]
    assert len(entries) == 4
    assert all(e['callerEvidence'] == 'no-unique-old-indexed-correspondence' for e in entries)
    assert all(e['anchorCall']['form'] == 'unqualified' and e['matchingNominal']['line'] == 1 for e in entries)
    assert [e['anchorCall']['site']['line'] for e in entries] == [3, 3, 5, 5]
    assert [e['targetCall']['site']['line'] for e in entries] == [4, 6, 4, 6]
    text = subprocess.check_output([binary, str(root / 'before'), str(root / 'after'), '--text']).decode()
    assert '\u65e2\u5b58\u6761\u4ef6' in text and 'callee\u3067\u306f\u306a\u3044' in text
    results.append({'case': 'result-spelling-existing-producer', 'report': report})
    text_samples.append('Case: result-spelling-existing-producer\n' + text)

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
        assert len(report['contexts']) == (2 if case['name'] == 'dispatch-growth' else 1 if expected else 0), case['name']
        if expected:
            target = next(t for t in report['contexts'] if t['kind'] == 'function')
            assert target['after']['file'] == 'Logger.swift'
            assert target['after']['line'] == 2
            assert target['after']['declaration'] == 'Logger.record(_:)'
            assert target['fileUnchanged'] is True
            assert len(target['entries']) == expected
            for path in target['entries']:
                entry = path['existingCall']['evidence']
                assert entry['beforeExistingCall']['line'] == 4
                assert entry['afterExistingCall']['line'] == 5
                assert entry['newOrChangedCall']['line'] == 6
                assert entry['beforeReceiver']['line'] == entry['afterReceiver']['line'] == 2
                assert entry['sharedArgumentSpellings'] == ['event']
        if case['name'] == 'dispatch-growth':
            typed = next(t for t in report['contexts'] if t['kind'] == 'struct')
            assert typed['after']['file'] == 'Analytics.swift' and typed['fileUnchanged']
            assert len(typed['entries']) == 2
            assert all(e['changedType']['evidence']['reference']['written'] == 'Analytics' for e in typed['entries'])
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
        # These previously read OSS changes had no eligible adjacent-call/type path.
        # Record any new member-spelling route separately; this is a known replay.
        # Record rejection reasons; zero is not evidence about their design.
        assert all('existingCall' not in e and 'changedType' not in e for t in report['contexts'] for e in t['entries']), case['id']
        results.append({'case': case['id'], 'report': report})
        if args.text_output:
            text_samples.append('Case: ' + case['id'] + '\n' + subprocess.check_output([binary, str(root / 'before'), str(root / 'after'), '--text']).decode())

args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'meaning': 'Syntax candidates, not design judgement or review benefit.', 'results': results}, indent=2) + '\n')
if args.text_output:
    args.text_output.parent.mkdir(parents=True, exist_ok=True)
    args.text_output.write_text('\n'.join(text_samples))
print('PASS: deterministic context, file counts/locations, hidden metadata, malformed input and symlink rejection')
