"""Own source controls only; supplied Swift is parsed, never executed."""
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
fixtures = Path(__file__).parent / 'CallbackFixtures'
before = (fixtures / 'before/Example.swift').read_text()
after = (fixtures / 'after/Example.swift').read_text()
assembled = (fixtures / 'assembled/Example.swift').read_text()

with tempfile.TemporaryDirectory(prefix='sekka-callback-check-') as temp:
    root = Path(temp)
    old, new = root / 'before', root / 'after'
    old.mkdir(); new.mkdir()

    def run(source, old_source=before, text=False, failure=False):
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

    result = run(after)
    change, = result['changes']
    assert not result['unknown'] and change['kind'] == 'expanded-written-relay'
    assert len(change['before']['passes']) == 1
    path = change['after']
    assert [(p['field'], p['destination'], p['declaration']['line'], p['argument']['line']) for p in path['passes']] == [
        ('Screen.onResume', 'Panel.onResume', 7, 8), ('Panel.onResume', 'Leaf.onSelect', 11, 12)]
    assert path['terminal'] == 'Leaf.onSelect'
    assert path['terminalDeclaration'] == {'file': 'Example.swift', 'line': 3}
    assert path['invocation'] == {'file': 'Example.swift', 'line': 4}
    assert path['callers'] == [{'file': 'Example.swift', 'line': 14}]
    assert 'calling site' in change['comparison']['alternative']
    text = run(after, text=True)
    assert all(word in text for word in ('1 → 2', 'Compare:', 'Benefit:', 'Conditions:', 'Limits:'))
    if args.output:
        Path(args.output).write_text(json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
    if args.text_output:
        Path(args.text_output).write_text(text)
    print(text)

    negatives = {
        'unchanged': before,
        'middle-use': after.replace('var body: Leaf {', 'func log(_ item: Item) { onResume(item) }\n  var body: Leaf {'),
        'wrapper': after.replace('Leaf(onSelect: onResume)', 'Leaf(onSelect: { onResume($0) })'),
        'shadow-field': after.replace('var body: Leaf { Leaf(onSelect: onResume) }', 'func view(onResume: @escaping (Item) -> Void) -> Leaf { Leaf(onSelect: onResume) }'),
        'accessor-parameter': after.replace('var body: Panel { Panel(onResume: onResume) }', 'var proxy: (Item) -> Void { get { fatalError() } set(onResume) { _ = Panel(onResume: onResume) } }'),
        'closure-capture': after.replace('var body: Panel { Panel(onResume: onResume) }', 'var proxy: Panel { let make = { [onResume = { (_: Item) in }] in Panel(onResume: onResume) }; return make() }'),
        'shadow-factory': after + '\nfunc Panel(onResume: (Item) -> Void) -> Panel { fatalError() }\n',
        'local-nominal': after.replace('var body: Panel { Panel(onResume: onResume) }', 'var body: Any { struct Panel { let onResume: (Item) -> Void }; return Panel(onResume: onResume) }'),
        'custom-init': after.replace('struct Panel {', 'struct Panel { init(onResume: @escaping (Item) -> Void) { self.onResume = onResume }'),
        'conditional-owner': after.replace('struct Panel {', 'struct Panel {\n#if DEBUG\nlet debug: Int\n#endif'),
        'duplicate-field': after.replace('struct Panel {', 'struct Panel { let onResume: (Item) -> Void'),
        'different-signature': after.replace('struct Panel {\n  let onResume: (Item) -> Void', 'struct Panel {\n  let onResume: (Int) -> Void'),
        'no-terminal-use': after.replace('onSelect(item)', ''),
    }
    for label, source in negatives.items():
        assert not run(source)['changes'], label
    generic = after.replace('func makeScreen() -> Screen { Screen(onResume: { _ in }) }', 'protocol Factory { init(onResume: @escaping (Item) -> Void) }\nfunc makeScreen<Screen: Factory>() -> Screen { Screen(onResume: { _ in }) }')
    assert not run(generic)['changes'], 'generic-callee-shadow'
    for implicit in ('newValue', 'oldValue'):
        keyword = 'set' if implicit == 'newValue' else 'didSet'
        base = before.replace('onResume', implicit)
        source = after.replace('onResume', implicit).replace(f'var body: Panel {{ Panel({implicit}: {implicit}) }}',
            f'var proxy: (Item) -> Void {{ {keyword} {{ _ = Panel({implicit}: {implicit}) }} }}' if keyword == 'didSet' else
            f'var proxy: (Item) -> Void {{ get {{ fatalError() }} set {{ _ = Panel({implicit}: {implicit}) }} }}')
        assert not run(source, old_source=base)['changes'], implicit
    removed, = run(assembled, old_source=after)['changes']
    assert removed['kind'] == 'removed-written-root-field' and 'after' not in removed and 'comparison' not in removed
    run('struct Broken {', failure=True)
    (new / 'Other.swift').symlink_to(new / 'Example.swift')
    run(after, failure=True)
    (new / 'Other.swift').unlink()
    (new / 'Other.swift').write_bytes(b'\xff')
    run(after, failure=True)
    (new / 'Other.swift').unlink()
    (new / '.hidden.swift').write_text('struct Broken {')
    run(after, failure=True)
    (new / '.hidden.swift').unlink()
    print(f'PASS: growth evidence/alternative, removal, {len(negatives) + 3} negative controls, 4 input failures; all repeated byte-for-byte')
