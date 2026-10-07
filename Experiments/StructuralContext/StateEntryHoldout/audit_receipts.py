"""Check frozen local evidence without executing OSS or rerunning the probe."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import re


def sha(data):
    return hashlib.sha256(data).hexdigest()


def check(value, message):
    if not value:
        raise ValueError(message)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    root, own = args.root, Path(__file__).parent
    load = lambda path: json.loads((root / path).read_bytes())
    freeze, selection, cases = load('freeze.json'), load('selection.json'), load('inputs.json')
    execution, validation = load('replay/execution.json'), load('input-validation.json')
    checkpoints = load('reviews/stage1-receipts.json')
    check(selection['planSHA256'] == freeze['planSHA256'] == sha((own / 'plan.md').read_bytes()), 'Plan binding')
    check(selection['selectorSHA256'] == sha((own / 'select_inputs.py').read_bytes()), 'Selector binding')
    check(execution['runnerSHA256'] == sha((own / 'run.py').read_bytes()), 'Runner binding')
    check(execution['inputsManifestSHA256'] == sha((root / 'inputs.json').read_bytes()), 'Manifest binding')
    check(sha((root / 'state-probe').read_bytes()) == execution['binarySHA256'] == freeze['binarySHA256'], 'Binary binding')
    prototype = own.parent / 'StateOperations/Prototype'
    for key, path in [('sourceSHA256', 'Sources/state-probe/main.swift'), ('packageSHA256', 'Package.swift'), ('resolvedSHA256', 'Package.resolved'), ('controlsRunnerSHA256', 'controls.py')]:
        check(sha((prototype / path).read_bytes()) == freeze[key], key)
    check(execution['sourceSHA256'] == freeze['sourceSHA256'], 'Execution source binding')
    ids = [c['id'] for c in cases]
    check(ids == ['Ice-528', 'KeyboardShortcuts-216'], 'Fixed two inputs')
    check(ids == [r['case'] for r in execution['results']] == [r['case'] for r in validation['cases']], 'Receipt case inventory')
    spec = importlib.util.spec_from_file_location('diff_verifier', own.parent / 'BothSideHoldout/verify_diff.py')
    verifier = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(verifier)
    rows = []
    for case, selected, run, bound in zip(cases, selection['cases'], execution['results'], validation['cases']):
        check(all(case[k] == selected[k] for k in ('repository', 'number', 'before', 'after', 'prefix')), 'Selected refs/scope')
        changes = [{k: v for k, v in c.items() if k != 'previous_filename' or v is not None} for c in selected['changes']]
        check(case['changes'] == changes, 'Changed-file inventory')
        packet, sources, count = root / 'packet' / case['id'], {}, 0
        for index, side in enumerate(('before', 'after')):
            folder = packet / side
            paths = list(folder.rglob('*'))
            check(not folder.is_symlink() and not any(p.is_symlink() for p in paths), 'No source symlinks')
            entries = [e for e in case['files'] if e['side'] == side]
            expected = {e['path']: e for e in entries}
            check(len(entries) == len(expected), 'No duplicate source paths')
            check({p.relative_to(folder).as_posix() for p in paths if p.is_file()} == set(expected), 'Complete packet inventory')
            sources[side], scope = {}, []
            for path, entry in expected.items():
                data = (folder / path).read_bytes()
                blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
                check(len(data) == entry['bytes'] and sha(data) == entry['sha256'] and blob == entry['blob'], 'Source size/hash/blob')
                check(entry['mode'] in ('100644', '100755'), 'Supported Git mode')
                sources[side][path] = data, entry['mode']
                if path.startswith(case['prefix']) and path.endswith('.swift'):
                    relative = path[len(case['prefix']):]
                    if not any(part.startswith('.') for part in relative.split('/')):
                        scope.append([relative, data.decode('utf-8')])
            scope.sort(key=lambda pair: pair[0].encode())
            digest = sha(json.dumps(scope, ensure_ascii=False, separators=(',', ':')).encode())
            check(len(scope) == run['files'][index] and digest == run[side + 'InputSHA256'], 'Actual analyzed scope')
            count += len(entries)
        diff = (packet / 'ordinary.diff').read_bytes()
        check(sha(diff) == case['diffSHA256'] == bound['diffSHA256'], 'Diff bytes')
        check(verifier.verify_diff(sources['before'], sources['after'], case['changes'], diff) == bound['files'], 'All hunks/gaps/tails')
        check(sha((packet / 'pr-context.md').read_bytes()) == case['prContextSHA256'], 'Context bytes')
        for name in ('json', 'text'):
            data = (root / 'replay' / (case['id'] + '.' + name)).read_bytes()
            stderr = (root / 'replay' / (case['id'] + '.' + name + '.stderr')).read_bytes()
            receipt = run['formats'][name]
            check(receipt['exit'] == 0 and receipt['fullProcessBytesEqual'], 'Successful repeat receipt')
            check(sha(data) == receipt['stdoutSHA256'] and len(data) == receipt['bytes'] and len(data.splitlines()) == receipt['lines'], 'Output bytes/counts')
            check(stderr == b'' and sha(stderr) == receipt['stderrSHA256'], 'Empty stderr binding')
        report = load('replay/' + case['id'] + '.json')
        check(len(report['relationships']) == run['relationships'], 'Group count')
        check([report['beforeFiles'], report['afterFiles']] == run['files'], 'Report file counts')
        check(all(report[s + 'InputSHA256'] == run[s + 'InputSHA256'] for s in ('before', 'after')), 'Report scope hashes')
        headers = {('diff --git a/' + c.get('previous_filename', c['filename']) + ' b/' + c['filename'] + '\n').encode() for c in changes if c['filename'].endswith('.swift') or c.get('previous_filename', '').endswith('.swift')}
        markers = list(re.finditer(rb'^diff --git .+\n', diff, re.M))
        check(markers and markers[0].start() == 0 and {m.group() for m in markers if m.group() in headers} == headers, 'Swift diff sections')
        swift_diff = b''.join(diff[m.start():markers[i+1].start() if i+1 < len(markers) else len(diff)] for i, m in enumerate(markers) if m.group() in headers)
        material = load('review-material-' + case['id'] + '-both.json')
        check(material['inputsSHA256'] == execution['inputsManifestSHA256'] and material['binarySHA256'] == freeze['binarySHA256'], 'Material provenance')
        check(material['preparerSHA256'] == sha((own / 'prepare_reviews.py').read_bytes()), 'Preparer binding')
        check(len(material['materials']) == 1, 'One case per packet receipt')
        row = material['materials'][0]
        check(row['case'] == case['id'] and row['ordinarySwiftDiffBytes'] == len(swift_diff) and row['ordinarySwiftDiffSHA256'] == sha(swift_diff) and row['prContextSHA256'] == case['prContextSHA256'], 'Material source provenance')
        reviews = {}
        for group in ('A', 'B'):
            folder = root / 'review-material' / case['id'] / group
            actual = {p.name: sha(p.read_bytes()) for p in folder.iterdir() if p.is_file()}
            required = {'pr-context.md', 'ordinary-swift.diff'} | ({'relations.text'} if group == 'B' else set())
            check(set(actual) == required and actual == row['groups'][group], 'Material boundary/bytes')
            check(actual['pr-context.md'] == case['prContextSHA256'] and actual['ordinary-swift.diff'] == sha(swift_diff), 'Equal common material')
            if group == 'B':
                check(actual['relations.text'] == run['formats']['text']['stdoutSHA256'], 'B text only supplement')
            checkpoint = (root / 'reviews' / case['id'] / (group + '-stage1.md')).read_bytes()
            saved = checkpoints[case['id'] + '/' + group]
            check(sha(checkpoint) == saved['sha256'] and len(checkpoint) == saved['bytes'], 'Immutable initial checkpoint')
            final = (root / 'reviews' / case['id'] / (group + '-final.md')).read_bytes()
            reviews[group] = dict(stage1SHA256=sha(checkpoint), finalSHA256=sha(final), finalBytes=len(final))
        rows.append(dict(case=case['id'], validatedEntries=count, groups=run['relationships'], reviews=reviews))
    result = dict(meaning='Saved evidence consistency; not signed execution proof or utility', auditorSHA256=sha(Path(__file__).read_bytes()), binarySHA256=freeze['binarySHA256'], validatedEntries=sum(r['validatedEntries'] for r in rows), cases=rows)
    with args.output.open('x') as f:
        f.write(json.dumps(result, indent=2) + '\n')
    print('PASS', len(rows), 'cases;', result['validatedEntries'], 'source entries')


if __name__ == '__main__':
    main()
