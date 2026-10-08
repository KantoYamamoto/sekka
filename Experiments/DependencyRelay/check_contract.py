"""Own controls: API evolution and caller pairing, not runtime equivalence."""
import argparse
import json
from pathlib import Path
import subprocess
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('binary')
parser.add_argument('--output')
parser.add_argument('--text-output')
args = parser.parse_args()
binary = str(Path(args.binary).resolve())
fixtures = Path(__file__).parent / 'ContractFixtures'
before = (fixtures / 'before/Example.swift').read_text()
after = (fixtures / 'after/Example.swift').read_text()
with tempfile.TemporaryDirectory(prefix='sekka-contract-check-') as temp:
    root = Path(temp)
    old, new = root / 'before', root / 'after'
    old.mkdir(); new.mkdir()

    def run(source=after, old_source=before, text=False, failure=False):
        (old / 'Example.swift').write_text(old_source)
        (new / 'Example.swift').write_text(source)
        command = [binary, str(old), str(new)] + (['--text'] if text else [])
        first = subprocess.run(command, capture_output=True, timeout=10)
        second = subprocess.run(command, capture_output=True, timeout=10)
        assert (first.returncode, first.stdout, first.stderr) == (second.returncode, second.stdout, second.stderr)
        if failure:
            assert first.returncode == 2 and not first.stdout and first.stderr
            return
        assert first.returncode == 0, first.stderr
        return first.stdout.decode() if text else json.loads(first.stdout)

    result = run()
    change, = result['changes']
    assert not result['unknown'] and change['api'] == 'Grid.init(onTap:)'
    assert change['beforeDeclaration'] == change['afterDeclaration'] == {'file': 'Example.swift', 'line': 3}
    assert [a['after']['line'] for a in change['adaptations']] == [7, 8, 9]
    assert all(a['discardedSlots'] == [1] for a in change['adaptations'])
    assert len(change['comparison']['alternatives']) == 3
    text = run(text=True)
    assert all(term in text for term in ('├─', '3 existing closure', 'Question:', 'Compare:', 'initial caller migration', 'Conditions:', 'Limits:'))
    if args.output:
        Path(args.output).write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    if args.text_output:
        Path(args.text_output).write_text(text)

    # One meaningful caller: controls change the reason/pairing, not just counts.
    old_one = '\n'.join(line for line in before.splitlines() if not any(word in line for word in ('func implicit', 'func branched', 'func unused'))) + '\n'
    new_one = '\n'.join(line for line in after.splitlines() if not any(word in line for word in ('func implicit', 'func branched', 'func unused'))) + '\n'
    negatives = {
        'uses-new-context': new_one.replace('{ item, _ in open(item) }', '{ item, context in open(item + context) }'),
        'body-changed': new_one.replace('open(item)', 'open(item + 1)'),
        'old-slot-type-changed': new_one.replace('(Element, Int)', '(String, Int)'),
        'return-changed': new_one.replace('-> Void', '-> Int'),
        'other-argument-changed': new_one.replace('data: [1]', 'data: [2]'),
        'body-local-shadow': new_one.replace('open(item)', 'let item = 2; open(item)'),
        'nested-closure': new_one.replace('open(item)', 'let callback = { open(item) }; callback()'),
        'callee-shadow': new_one + 'func Grid(data: [Int], onTap: (Int, Int) -> Void) {}\n',
        'duplicate-constructor': new_one.replace('  let onTap:', '  init() { fatalError() }\n  let onTap:'),
        'duplicate-call-pair': new_one.replace('_ = Grid(data: [1], onTap: { item, _ in open(item) })', '_ = Grid(data: [1], onTap: { item, _ in open(item) }); _ = Grid(data: [1], onTap: { item, _ in open(item) })'),
    }
    for label, source in negatives.items():
        assert not run(source, old_source=old_one)['changes'], label
    assert not run(before)['changes'], 'unchanged'
    assert not run(new_one.replace('(Element, Int)', '(Element)'), old_source=old_one)['changes'], 'same-arity'
    old_catch = old_one.replace('{ item in open(item) }', '{ error in do { try operation() } catch { open(error) } }')
    new_catch = new_one.replace('{ item, _ in open(item) }', '{ item, _ in do { try operation() } catch { open(item) } }')
    assert not run(new_catch, old_source=old_catch)['changes'], 'implicit-catch-shadow'
    reference = run(new_one, old_source=old_one.replace('{ item in open(item) }', 'open'))
    assert not reference['changes'] and any('direct references' in u['reason'] for u in reference['unknown'])
    # A renamed member label remains literal, not a normalized parameter reference.
    assert not run(new_one.replace('open(item)', 'item.item()'), old_source=old_one.replace('open(item)', 'item.value()'))['changes']
    run('struct Broken {', failure=True)
    (new / 'Other.swift').symlink_to(new / 'Example.swift')
    run(failure=True)
    (new / 'Other.swift').unlink()
    (new / 'Other.swift').write_bytes(b'\xff')
    run(failure=True)
    (new / 'Other.swift').unlink()
    (new / '.hidden.swift').write_text('struct Broken {')
    run(failure=True)
    (new / '.hidden.swift').unlink()
    (new / 'Directory.swift').mkdir()
    run(failure=True)
    (new / 'Directory.swift').rmdir()
    print(f'PASS: named/implicit/branched bodies, noop excluded, three alternatives, {len(negatives) + 5} negative controls, 5 input failures; repeated byte-for-byte')
