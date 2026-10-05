"""Build own diagnostic and verify syntax relationships and fail-closed boundaries."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

from analyze import analyze


def fixtures():
    dispatch = '''switch value {
case .a: sinkOld(input)
case .b: buffer.withOld { p in sink(p) }
}'''
    wrapped = '''struct Box {
init(_ value: Value, input: Int) { callback { BODY } }
static func report(_ value: Value, input: Int) { BODY }
var finalize: () -> Void { { Box.report(value, input: input) } }
}'''.replace('BODY', dispatch)
    changed = wrapped.replace('withOld', 'withNew')
    yield 'initializer-changed-helper-property-user', wrapped, changed
    yield 'unchanged', wrapped, wrapped
    yield 'already-shared-primary-rule', wrapped, changed + '\nfunc withNew() { primaryRule() }'
    yield 'different-arguments-or-purpose', wrapped.replace('buffer.withOld', 'buffer.withOld'), changed.replace('func report(_ value: Value, input: Int) { switch value', 'func report(_ value: Value, input: Int) { switch value').replace('sinkOld(input)', 'sinkOld(anotherPurpose)', 1)
    guarded = '#if FLAG\nfunc first() { BODY }\n#else\nfunc second() { BODY }\n#endif'.replace('BODY', dispatch)
    yield 'inactive-conditions-remain-unknown', guarded, guarded.replace('withOld', 'withNew')
    yield 'changed-owner-header-unpaired', wrapped, changed.replace('func report(_ value: Value, input: Int)', 'func reportRenamed(_ value: Value, input: Int)')
    yield 'added-deleted-regions', 'func alone() { ' + dispatch + ' }', changed
    duplicate = 'func first() { BODY BODY }\nfunc second() { BODY }'.replace('BODY', dispatch)
    yield 'duplicate-switch-not-paired-by-order', duplicate, duplicate.replace('withOld', 'withNew')
    yield 'ambiguous-declaration-header', 'func same() { BODY }\nfunc same() { BODY }'.replace('BODY', dispatch), 'func same() { BODY }\nfunc same() { BODY }'.replace('BODY', dispatch.replace('withOld', 'withNew'))
    conditional = '''func first() { switch value {
#if FLAG
case .a: old()
#endif
default: fallback()
} }
func second() { switch value {
#if FLAG
case .a: old()
#endif
default: fallback()
} }'''
    yield 'conditional-case-lists-unexpanded', conditional, conditional.replace('old()', 'new()')
    accessors = 'struct Box { var first: Int { get { BODY } } var second: Int { BODY } }'.replace('BODY', dispatch)
    yield 'explicit-and-implicit-getters', accessors, accessors.replace('withOld', 'withNew')
    yield 'function-header-and-local-type-boundaries', '''func caller(_ value: Int = source()) {
let stored = source()
struct Local { var closure = { source() } }
source()
}''', '''func caller(_ value: Int = source()) {
let stored = source()
struct Local { var closure = { source() } }
source()
}'''
    yield 'normal-zero-no-switch', 'struct A {}', 'struct B {}'


def verify_case(name, report, result):
    relations = result['relationships']
    expected = name in {'initializer-changed-helper-property-user', 'already-shared-primary-rule',
                        'different-arguments-or-purpose', 'inactive-conditions-remain-unknown', 'explicit-and-implicit-getters'}
    if bool(relations) != expected:
        raise ValueError('Unexpected relationship: ' + name)
    if expected:
        if len(relations) != 1 or len(relations[0]['members']) != 2:
            raise ValueError('Incomplete relationship: ' + name)
        if 'callee' not in result['unresolved'] or 'purpose' not in result['unresolved']:
            raise ValueError('Semantic uncertainty lost')
    if name == 'initializer-changed-helper-property-user':
        kinds = {m['after']['owner']['kind'] for m in relations[0]['members']}
        if kinds != {'function', 'initializer'}:
            raise ValueError('Initializer was not a distinct region')
        if not any(u['ownerState'] == 'token-identical' and u['call']['owner']['kind'] == 'property-body' for u in result['users']):
            raise ValueError('Unchanged property user not recorded')
        if not relations[0]['enclosingConditionsDiffer']:
            raise ValueError('Closure boundary lost')
    if name == 'different-arguments-or-purpose' and not relations[0]['argumentSpellingsDiffer']:
        raise ValueError('Arguments were silently equated')
    if name == 'inactive-conditions-remain-unknown' and not relations[0]['enclosingConditionsDiffer']:
        raise ValueError('Different lexical branches were conflated')
    reasons = {u['reason'] for u in result['unknown']}
    if name == 'duplicate-switch-not-paired-by-order' and 'added-deleted-or-ambiguous-switch' not in reasons:
        raise ValueError('Duplicate switches paired by position')
    if name == 'ambiguous-declaration-header' and 'ambiguous-owner' not in reasons:
        raise ValueError('Duplicate declaration not marked unknown')
    if name == 'conditional-case-lists-unexpanded' and 'conditional-case-list-not-expanded' not in reasons:
        raise ValueError('Conditional cases were treated as complete')
    if name == 'function-header-and-local-type-boundaries':
        calls = [c for c in report['after']['calls'] if c.get('selector') == 'source()']
        kinds = [c.get('owner', {}).get('kind') for c in calls]
        if kinds != [None, 'binding-initializer', 'binding-initializer', 'function']:
            raise ValueError('Header/binding/local type ownership mismatch: ' + repr(kinds))
        if calls[1]['owner']['key'] == calls[2]['owner']['key']:
            raise ValueError('Local type binding joined outer binding')


def run_twice(command):
    a = subprocess.run(command, capture_output=True)
    b = subprocess.run(command, capture_output=True)
    if (a.returncode, a.stdout, a.stderr) != (b.returncode, b.stdout, b.stderr):
        raise ValueError('Unstable exit/stdout/stderr bytes')
    return a


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--scratch', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--source-ref', default='HEAD')
    args = p.parse_args()
    repo = Path(__file__).resolve().parents[3]
    commit = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', args.source_ref + '^{commit}']).decode().strip()
    with tempfile.TemporaryDirectory(prefix='sekka-region-check-') as folder:
        root = Path(folder)
        archive_bytes = subprocess.check_output(['git', '-C', str(repo), 'archive', commit, 'Experiments/StructuralContext'])
        with tarfile.open(fileobj=io.BytesIO(archive_bytes)) as archive:
            for m in archive.getmembers():
                if m.name.startswith('/') or '..' in Path(m.name).parts or not (m.isfile() or m.isdir()):
                    raise ValueError('Invalid own archive entry')
            archive.extractall(root)
        package = root / 'Experiments/StructuralContext'
        entry = package / 'Sources/context-probe/main.swift'
        original = entry.read_text()
        if original.count('\ndo {') != 1:
            raise ValueError('Reader entry boundary changed')
        body = (package / 'CochangeDiagnostic/region-body.swift').read_text()
        entry.write_text(original.split('\ndo {', 1)[0] + '\n' + body)
        build = ['swift', 'build', '--package-path', str(package), '--scratch-path', str(args.scratch.resolve())]
        subprocess.run(build, check=True)
        binary = Path(subprocess.check_output(build + ['--show-bin-path']).decode().strip()) / 'context-probe'
        args.output.parent.mkdir(parents=True, exist_ok=True)
        frozen = args.output.with_name('region-probe')
        shutil.copyfile(binary, frozen); frozen.chmod(0o700)
        before, after = root / 'before', root / 'after'
        before.mkdir(); after.mkdir()
        command = [str(frozen.resolve()), str(before), str(after)]
        checks = []
        for name, old, new in fixtures():
            (before / 'Fixture.swift').write_text(old)
            (after / 'Fixture.swift').write_text(new)
            result = run_twice(command)
            if result.returncode != 0 or result.stderr:
                raise ValueError('Fixture parse failed: ' + name + '\n' + result.stderr.decode())
            report = json.loads(result.stdout)
            analyzed = analyze(report)
            verify_case(name, report, analyzed)
            checks.append({'case': name, 'exit': 0, 'fullProcessBytesEqual': True,
                           'relationships': len(analyzed['relationships']), 'unknown': len(analyzed['unknown'])})
        for name, bad in [('malformed', b'func {'), ('invalid-utf8', b'\xff')]:
            (after / 'Bad.swift').write_bytes(bad)
            result = run_twice(command)
            if result.returncode != 2 or result.stdout or not result.stderr:
                raise ValueError('Partial result or false zero: ' + name)
            checks.append({'case': name, 'exit': 2, 'fullProcessBytesEqual': True, 'noPartialOutput': True})
            (after / 'Bad.swift').unlink()
        link = after / 'Link.swift'; link.symlink_to(before / 'Fixture.swift')
        result = run_twice(command)
        if result.returncode != 2 or result.stdout:
            raise ValueError('Symlink produced partial output')
        checks.append({'case': 'symlink', 'exit': 2, 'fullProcessBytesEqual': True, 'noPartialOutput': True})
        args.output.write_text(json.dumps({'source': commit, 'binarySHA256': hashlib.sha256(frozen.read_bytes()).hexdigest(),
            'bodySHA256': hashlib.sha256(body.encode()).hexdigest(),
            'analyzerSHA256': hashlib.sha256(Path(__file__).with_name('analyze.py').read_bytes()).hexdigest(),
            'checks': checks, 'meaning': 'Own syntax controls; neither independent review nor unseen usefulness'}, indent=2) + '\n')
    print('PASS:', len(checks), 'cochange diagnostic syntax/zero/error controls, full process bytes twice')


if __name__ == '__main__':
    main()
