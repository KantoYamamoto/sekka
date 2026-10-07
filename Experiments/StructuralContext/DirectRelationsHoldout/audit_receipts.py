"""Audit saved private evidence; never execute the target or rerun the detector."""
import argparse
import hashlib
import json
from pathlib import Path
import re


def sha(data):
    return hashlib.sha256(data).hexdigest()


def check(condition, message):
    if not condition:
        raise ValueError(message)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    root = args.root
    load = lambda name: json.loads((root / name).read_bytes())
    cases = load('inputs.json')
    execution = load('replay/execution.json')
    all_modes = load('all-modes.json')
    validation = load('input-validation.json')
    selection = load('selection.json')
    ids = [c['id'] for c in cases]
    check(len(ids) == len(set(ids)) == 4, 'Frozen case inventory')
    check([(c['repository'], c['number']) for c in cases] == [(c['repository'], c['number']) for c in selection['cases']], 'Selected case order')
    for case, selected in zip(cases, selection['cases']):
        check(all(case[key] == selected[key] for key in ('before', 'after', 'prefix')), 'Selected refs')
        changes = [{k: v for k, v in row.items() if k != 'previous_filename' or v is not None} for row in selected['changes']]
        check(case['changes'] == changes, 'Selected changed-file inventory')
    check(set(ids) == {c['case'] for c in validation['cases']}, 'Diff receipt cases')
    check(len(validation['cases']) == len(cases), 'Duplicate diff receipt')
    check(ids == [c['case'] for c in execution['results']], 'Execution inventory')
    check(execution['inputsSHA256'] == sha((root / 'inputs.json').read_bytes()), 'Inputs hash')
    check(sha(args.binary.read_bytes()) == execution['binarySHA256'] == all_modes['binarySHA256'], 'Binary hash')
    check(len(all_modes['results']) == 8, 'All-mode inventory')
    rows = []
    for case, run in zip(cases, execution['results']):
        name = case['id']
        packet = root / 'packet' / name
        entry_count = 0
        for side in ('before', 'after'):
            folder = packet / side
            paths = list(folder.rglob('*'))
            check(not folder.is_symlink() and not any(p.is_symlink() for p in paths), 'Symlink packet')
            entries = [e for e in case['files'] if e['side'] == side]
            expected = {e['path']: e for e in entries}
            check(len(entries) == len(expected), 'Duplicate source entry')
            check({str(p.relative_to(folder)) for p in paths if p.is_file()} == set(expected), 'Source inventory')
            scope = []
            for path, entry in expected.items():
                data = (folder / path).read_bytes()
                blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
                check(len(data) == entry['bytes'] and sha(data) == entry['sha256'] and blob == entry['blob'], 'Source bytes')
                # Recorded Git modes were bound during materialization/diff verification.
                check(entry['mode'] in ('100644', '100755'), 'Unsupported Git mode')
                if path.startswith(case['prefix']) and path.endswith('.swift'):
                    relative = path[len(case['prefix']):]
                    if not any(part.startswith('.') for part in relative.split('/')):
                        scope.append([relative, data.decode('utf-8')])
            scope.sort(key=lambda pair: pair[0].encode('utf-8'))
            digest = sha(json.dumps(scope, ensure_ascii=False, separators=(',', ':')).encode())
            check(len(scope) == run['inputScopes'][side]['files'] and digest == run['inputScopes'][side]['sha256'], 'Analyzed scope')
            entry_count += len(entries)
        diff = (packet / 'ordinary.diff').read_bytes()
        check(sha(diff) == case['diffSHA256'], 'Ordinary diff bytes')
        bound = next(c for c in validation['cases'] if c['case'] == name)
        check(bound['diffSHA256'] == case['diffSHA256'] and len(bound['files']) == len(case['changes']), 'Diff binding')
        check(sha((packet / 'pr-context.md').read_bytes()) == case['prContextSHA256'], 'PR context')
        report_data = (root / 'replay' / (name + '.stdout')).read_bytes()
        report = json.loads(report_data)
        check(run['exit'] == 0 and run['fullProcessBytesEqual'] and run['textProcessBytesEqual'], 'Default process receipt')
        check(sha(report_data) == run['stdoutSHA256'] and len(report_data) == run['stdoutBytes'], 'Default JSON bytes')
        check(sha((root / 'replay' / (name + '.text')).read_bytes()) == run['textSHA256'], 'Default text bytes')
        check((root / 'replay' / (name + '.stderr')).read_bytes() == b'' and run['stderrSHA256'] == sha(b''), 'Default stderr')
        check(len(report['relationships']) == run['relationships'] and len(report['unknown']) == run['unknown'], 'Report counts')
        check(report['before'] == run['inputScopes']['before'] and report['after'] == run['inputScopes']['after'], 'Report scope')
        for mode, default_hash in [('all.json', run['stdoutSHA256']), ('all.text', run['textSHA256'])]:
            matches = [r for r in all_modes['results'] if r['case'] == name and r['mode'] == mode]
            check(len(matches) == 1, 'All-mode duplicate/missing')
            r = matches[0]
            data = (root / 'replay' / (name + '.' + mode)).read_bytes()
            check(r['exit'] == 0 and r['fullProcessBytesEqual'] and r['stderrSHA256'] == sha(b''), 'All-mode receipt')
            check(sha(data) == r['stdoutSHA256'] and len(data) == r['stdoutBytes'], 'All-mode bytes')
            check(report['omittedShapeDetails'] == 0 and sha(data) == default_hash, 'No-omission mode parity')
        reviews = root / 'reviews' / name
        checkpoint = json.loads((reviews / 'checkpoint.json').read_bytes())
        check(checkpoint['case'] == name and checkpoint['beforeCommonSource'], 'Checkpoint case/stage')
        material = {}
        headers = {('diff --git a/' + c.get('previous_filename', c['filename']) + ' b/' + c['filename'] + '\n').encode() for c in case['changes'] if c['filename'].endswith('.swift') or c.get('previous_filename', '').endswith('.swift')}
        markers = list(re.finditer(rb'^diff --git .+\n', diff, re.M))
        check(markers and markers[0].start() == 0 and {m.group() for m in markers if m.group() in headers} == headers, 'Swift diff sections')
        swift_diff = b''.join(diff[m.start():markers[i + 1].start() if i + 1 < len(markers) else len(diff)] for i, m in enumerate(markers) if m.group() in headers)
        for group in ('A', 'B'):
            directory = root / 'review-material' / name / group
            receipt = load('review-material-' + name + '-' + group + '.json')
            check(receipt['inputsSHA256'] == execution['inputsSHA256'] and receipt['binarySHA256'] == execution['binarySHA256'], 'Material provenance')
            row = receipt['materials'][0]
            check(len(receipt['materials']) == 1 and row['case'] == name, 'Material case')
            material[group] = {p.name: sha(p.read_bytes()) for p in directory.iterdir() if p.is_file()}
            check(material[group] == row['groups'][group], 'Material bytes')
            required = {'pr-context.md', 'ordinary-swift.diff'} | ({'relations.json', 'relations.text'} if group == 'B' else set())
            check(set(material[group]) == required, 'Material boundary')
            check(material[group]['pr-context.md'] == case['prContextSHA256'], 'Material context')
            check(material[group]['ordinary-swift.diff'] == sha(swift_diff), 'Ordinary Swift diff binding')
            stage1 = sha((reviews / (group + '-stage1.md')).read_bytes())
            check(stage1 == checkpoint['stage1'][group]['sha256'], 'Stage1 was modified')
            if group == 'B':
                check(material[group]['relations.json'] == run['stdoutSHA256'] and material[group]['relations.text'] == run['textSHA256'], 'B supplement')
        check(all(material['A'][n] == material['B'][n] for n in ('pr-context.md', 'ordinary-swift.diff')), 'Unequal ordinary materials')
        rows.append(dict(case=name, validatedEntries=entry_count, transitionCount=report['transitionCount'], unknown=report['unknown'], checkpointSHA256=sha((reviews / 'checkpoint.json').read_bytes()), materials=material))
    check(sum(r['validatedEntries'] for r in rows) == execution['validatedEntries'], 'Total source count')
    result = dict(meaning='Saved evidence consistency, not signed execution proof or utility', auditorSHA256=sha(Path(__file__).read_bytes()), inputsSHA256=execution['inputsSHA256'], binarySHA256=execution['binarySHA256'], validatedEntries=execution['validatedEntries'], cases=rows)
    with args.output.open('x') as output:
        output.write(json.dumps(result, ensure_ascii=False, indent=2) + '\n')
    print('PASS', len(rows), 'cases;', result['validatedEntries'], 'entries; common materials/checkpoints/all modes bound')


if __name__ == '__main__':
    main()
