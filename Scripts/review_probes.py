"""Exercise known Swift changes without claiming semantic review coverage."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


def run(binary, cases_path, output):
    binary = binary.resolve()
    cases = json.loads(cases_path.read_text())
    results = []
    for case in cases:
        with tempfile.TemporaryDirectory(prefix='sekka-probe-') as temporary:
            root = Path(temporary)
            for side in ('before', 'after'):
                (root / side).mkdir()
                for name, source in case[side].items():
                    path = root / side / name
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_text(source + '\n')
            args = [str(binary), 'diff', '--before', str(root / 'before'), '--after', str(root / 'after')]
            process = subprocess.run(args + ['--format', 'json'], capture_output=True, text=True)
            if process.returncode != case['exitCode']:
                raise AssertionError(f"{case['name']}: expected exit {case['exitCode']}, got {process.returncode}: {process.stderr}")
            result = {'name': case['name'], 'question': case['question'], 'exitCode': process.returncode}
            if process.returncode == 0:
                report = json.loads(process.stdout)
                text = subprocess.check_output(args, text=True)
                result.update(
                    rules=[f['rule'] for f in report['findings']],
                    files=report['coverage']['changedFiles'],
                    bodies=report['coverage']['bodyComparisons'],
                    compared=report['coverage']['comparedBodyCount'],
                    skipped=report['coverage']['skippedBodyCount'],
                    textCharacters=len(text),
                    notComparedTextEntries=text.count('[not-compared]'),
                )
            else:
                result['error'] = process.stderr.strip()
            results.append(result)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({
        'binarySHA256': hashlib.sha256(binary.read_bytes()).hexdigest(),
        'casesSHA256': hashlib.sha256(cases_path.read_bytes()).hexdigest(),
        'meaning': 'Known-input observations and expected exit codes; not semantic coverage or review efficiency.',
        'results': results,
    }, indent=2) + '\n')
    for result in results:
        statuses = [b['status'] for b in result.get('bodies', [])]
        print(result['name'], 'exit=' + str(result['exitCode']), result.get('rules', []), sorted(set(statuses)))
    print('Saved', output)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, default=Path('.build/debug/sekka'))
    parser.add_argument('--cases', type=Path, default=Path('Fixtures/probes/cases.json'))
    parser.add_argument('--output', type=Path, default=Path('.build/review-probes.json'))
    args = parser.parse_args()
    run(args.binary, args.cases, args.output)
