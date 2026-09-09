"""Run fixed structural cases against the experimental CLI, not assess design quality."""
import argparse
import json
import os
import stat
from pathlib import Path
import subprocess
import tempfile


def main(binary, output):
    repository = Path(__file__).resolve().parents[2]
    cases = json.loads((repository / 'Fixtures/structural-reconsideration/cases.json').read_text())
    expected = {'dispatch-spread': (0, 3), 'dispatch-growth': (1, 3), 'dispatch-separate-policy': (0, 3)}
    results = []
    for case in cases:
        with tempfile.TemporaryDirectory(prefix='sekka-call-sequence-') as directory:
            root = Path(directory)
            for side in ['before', 'after']:
                (root / side).mkdir()
                for file, source in case[side].items():
                    (root / side / file).write_text(source)
            args = [str(binary.resolve()), str(root / 'before'), str(root / 'after')]
            result = subprocess.run(args, capture_output=True, text=True, check=True)
            report = json.loads(result.stdout)
            assert report['beforeFileCount'] == len(case['before'])
            assert report['afterFileCount'] == len(case['after'])
            expansions = report['expansions']
            if case['name'] in expected:
                assert len(expansions) == 1, (case['name'], expansions)
                item = expansions[0]
                assert (len(item['before']), len(item['after'])) == expected[case['name']]
                for side in ['before', 'after']:
                    for site in item[side]:
                        lines = case[side][site['file']].splitlines()
                        assert lines[site['line'] - 1].strip() == 'logger.record(event)'
                        assert lines[site['endLine'] - 1].strip() == 'analytics.record(event)'
                if case['name'] == 'dispatch-growth':
                    assert item['before'][0]['file'] == 'Checkout.swift'
                    assert case['before']['Checkout.swift'] == case['after']['Checkout.swift']
            else:
                assert expansions == [], (case['name'], expansions)
            assert subprocess.check_output(args, text=True) == result.stdout
            results.append({'case': case['name'], 'report': report})
    with tempfile.TemporaryDirectory(prefix='sekka-call-errors-') as directory:
        root = Path(directory)
        (root / 'before').mkdir(); (root / 'after').mkdir()
        (root / 'after' / 'broken.swift').write_text('struct {')
        args = [str(binary.resolve()), str(root / 'before'), str(root / 'after')]
        result = subprocess.run(args, capture_output=True, text=True)
        assert result.returncode == 2 and result.stdout == '' and 'Cannot parse' in result.stderr
        (root / 'after' / 'broken.swift').unlink()
        (root / 'after' / 'link.swift').symlink_to(root / 'missing.swift')
        result = subprocess.run(args, capture_output=True, text=True)
        assert result.returncode == 2 and result.stdout == ''
    # A dot-prefixed ancestor/root must not make visible descendants disappear.
    with tempfile.TemporaryDirectory(prefix='sekka-call-hidden-') as directory:
        root = Path(directory) / '.parent'
        root.mkdir()
        for side in ['before', '.after']:
            (root / side).mkdir()
            (root / side / '.ignored').mkdir()
            (root / side / '.ignored' / 'bad.swift').write_text('struct {')
        (root / 'before' / 'A.swift').write_text('func a() { x(); y() }')
        (root / '.after' / 'A.swift').write_text('func a() { x(); y() }\nfunc b() { x(); y() }')
        if hasattr(os, 'chflags') and hasattr(stat, 'UF_HIDDEN'):
            os.chflags(root / 'before' / 'A.swift', stat.UF_HIDDEN)
            os.chflags(root / '.after' / 'A.swift', stat.UF_HIDDEN)
        args = [str(binary.resolve()), str(root / 'before'), str(root / '.after')]
        report = json.loads(subprocess.check_output(args, text=True))
        assert report['beforeFileCount'] == report['afterFileCount'] == 1
        assert len(report['expansions']) == 1
        assert all(site['file'] == 'A.swift' for side in ['before', 'after'] for site in report['expansions'][0][side])
        identical = json.loads(subprocess.check_output([args[0], args[2], args[2]], text=True))
        assert identical['expansions'] == [] and identical['beforeFileCount'] == 1
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({'meaning': 'Syntax extraction checks; not design judgement or review benefit.', 'results': results}, ensure_ascii=False, indent=2) + '\n')
    print('PASS: 7 fixed cases, stable JSON/source positions, malformed input and symlink failure')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--binary', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    main(args.binary, args.output)
