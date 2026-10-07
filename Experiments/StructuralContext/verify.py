"""Own direct-relation CLI controls; not unseen utility or independent review."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile


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
    duplicate = 'func first() { BODY\nBODY }\nfunc second() { BODY }'.replace('BODY', dispatch)
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
    accessors = 'struct Box { var first: Int { get { BODY } }\nvar second: Int { BODY } }'.replace('BODY', dispatch)
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
    trailing = '''func first() { switch value {
case .a: old {} success: {}
case .b: fallback()
} }
func second() { switch value {
case .a: old {} LABEL: {}
case .b: fallback()
} }'''
    yield 'different-additional-trailing-labels', trailing.replace('LABEL', 'failure'), trailing.replace('LABEL', 'failure').replace('old', 'new')
    yield 'same-additional-label-transition', trailing.replace('LABEL', 'success'), trailing.replace('LABEL', 'success').replace('success', 'failure')
    closures = 'func first() { switch value { case .a: old { 1 }; case .b: fallback() } }\nfunc second() { switch value { case .a: old { 2 }; case .b: fallback() } }'
    yield 'different-trailing-closure-arguments', closures, closures.replace('old', 'new')
    for name, wrapper, changed_header in [
        ('else-if-condition-change', 'if outerA {} else if inner { BODY }', ('outerA', 'outerB')),
        ('while-condition-change', 'while outerA { BODY }', ('outerA', 'outerB')),
        ('repeat-condition-change', 'repeat { BODY } while outerA', ('outerA', 'outerB')),
        ('for-sequence-change', 'for item in outerA { BODY }', ('outerA', 'outerB')),
        ('guard-else-condition-change', 'guard outerA else { BODY; return }', ('outerA', 'outerB')),
        ('catch-condition-change', 'do { work() } catch where outerA { BODY }', ('outerA', 'outerB')),
    ]:
        old = 'func first() { ' + wrapper.replace('BODY', dispatch) + ' }\nfunc second() { ' + dispatch + ' }'
        new = old.replace('withOld', 'withNew').replace(*changed_header)
        yield name, old, new
    subscripts = 'struct Box { subscript(index: Int) -> Int { get { BODY } }\nvar other: Int { BODY } }'.replace('BODY', dispatch)
    yield 'subscript-header-change', subscripts, subscripts.replace('withOld', 'withNew').replace('index: Int', 'index: String')



def run_twice(command):
    a = subprocess.run(command, capture_output=True)
    b = subprocess.run(command, capture_output=True)
    if (a.returncode, a.stdout, a.stderr) != (b.returncode, b.stdout, b.stderr):
        raise ValueError('Unstable complete process bytes')
    return a


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--binary', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--text-output', type=Path, required=True)
    args = p.parse_args()
    binary = args.binary.resolve()
    binary_sha = hashlib.sha256(binary.read_bytes()).hexdigest()
    checks = []
    expected = {'initializer-changed-helper-property-user', 'already-shared-primary-rule',
                'different-arguments-or-purpose', 'inactive-conditions-remain-unknown',
                'explicit-and-implicit-getters', 'same-additional-label-transition',
                'different-trailing-closure-arguments'}
    with tempfile.TemporaryDirectory(prefix='sekka-relations-') as folder:
        root = Path(folder); before = root / 'before'; after = root / 'after'
        before.mkdir(); after.mkdir()
        command = [str(binary), str(before), str(after)]
        for name, old, new in fixtures():
            (before / 'Fixture.swift').write_text(old)
            (after / 'Fixture.swift').write_text(new)
            output = run_twice(command)
            text = run_twice(command + ['--text'])
            full = run_twice(command + ['--all'])
            if output.returncode != 0 or output.stderr or text.returncode != 0 or text.stderr or full.returncode != 0 or full.stderr:
                raise ValueError('Failed input: ' + name)
            report = json.loads(output.stdout)
            if bool(report['relationships']) != (name in expected):
                raise ValueError('Wrong relationship: ' + name)
            if json.loads(full.stdout) != report:
                raise ValueError('Full mode changed facts for small fixture: ' + name)
            if name in expected and (len(report['relationships']) != 1 or len(report['relationships'][0]['members']) != 2):
                raise ValueError('Incomplete relationship: ' + name)
            if name == 'initializer-changed-helper-property-user':
                r = report['relationships'][0]
                if {m['after']['owner']['kind'] for m in r['members']} != {'initializer', 'function'}:
                    raise ValueError('Owner lost')
                if not any(u['ownerState'] == 'token-identical' and u['owner']['kind'] == 'property-body' for u in r['users']):
                    raise ValueError('Existing property user lost')
                # Own synthetic text is safe in CI artifacts; third-party body never published.
                args.text_output.parent.mkdir(parents=True, exist_ok=True)
                args.text_output.write_bytes(text.stdout)
            if name in {'different-arguments-or-purpose', 'different-trailing-closure-arguments'} and not report['relationships'][0]['argumentSpellingsDiffer']:
                raise ValueError('Argument difference hidden')
            if name == 'already-shared-primary-rule' and not any(c['sameBasenameDeclarations'] for c in report['relationships'][0]['introducedCommonCallSpellings']):
                raise ValueError('Counter-evidence lost')
            checks.append({'case': name, 'exit': 0, 'fullProcessBytesEqual': True,
                           'relationships': len(report['relationships']), 'unknown': len(report['unknown']),
                           'jsonTextAllChecked': True})
        # Foundation's URL String reader strips BOM; raw-byte decoding must retain it.
        old = next(fixtures())[1]; new = next(fixtures())[2]
        (before / 'Fixture.swift').write_text(old)
        (after / 'Fixture.swift').write_text(old)
        plain = json.loads(run_twice(command).stdout)
        raw = b'\xef\xbb\xbf' + old.encode()
        (after / 'Fixture.swift').write_bytes(raw)
        result = run_twice(command)
        bom = json.loads(result.stdout)
        if result.returncode or bom['after']['sha256'] == plain['after']['sha256']:
            raise ValueError('BOM was removed from fingerprint')
        checks.append({'case': 'bom-fingerprint-preserved', 'exit': 0, 'fullProcessBytesEqual': True})
        raw = b'\xef\xbb\xbf' + new.encode()
        (after / 'Fixture.swift').write_bytes(raw)
        result = run_twice(command)
        report = json.loads(result.stdout)
        if result.returncode or len(report['relationships']) != 1:
            raise ValueError('BOM source did not produce relation')
        for m in report['relationships'][0]['members']:
            offset = m['after']['site']['offset']
            if raw[offset:offset+6] != b'switch':
                raise ValueError('BOM physical byte offset wrong')
        checks.append({'case': 'bom-physical-offset-preserved', 'exit': 0, 'fullProcessBytesEqual': True})
        # Trivia is not syntax change. Input hash still identifies the exact source bytes.
        source = next(fixtures())[1]
        (before / 'Fixture.swift').write_text(source)
        (after / 'Fixture.swift').write_text('// extra comment\n' + source.replace('switch value', 'switch  value'))
        result = run_twice(command)
        if result.returncode or json.loads(result.stdout)['relationships']:
            raise ValueError('Trivia became structural relation')
        checks.append({'case': 'trivia-only', 'exit': 0, 'fullProcessBytesEqual': True})
        for name, bad in [('malformed', b'func {'), ('invalid-utf8', b'\xff')]:
            (after / 'Bad.swift').write_bytes(bad)
            for flags in [[], ['--text'], ['--all']]:
                result = run_twice(command + flags)
                if result.returncode != 2 or result.stdout or not result.stderr:
                    raise ValueError('Partial output or false zero: ' + name)
            checks.append({'case': name, 'exit': 2, 'fullProcessBytesEqual': True, 'noPartialOutput': True})
            (after / 'Bad.swift').unlink()
        link = after / 'Link.swift'; link.symlink_to(before / 'Fixture.swift')
        result = run_twice(command)
        if result.returncode != 2 or result.stdout:
            raise ValueError('Symlink produced success')
        checks.append({'case': 'symlink', 'exit': 2, 'fullProcessBytesEqual': True, 'noPartialOutput': True})
        link.unlink()
        for name, invalid in [('missing-directory', [str(binary), str(root / 'absent'), str(after)]),
                              ('bad-flag', command + ['--unknown'])]:
            result = run_twice(invalid)
            if result.returncode != 2 or result.stdout or not result.stderr:
                raise ValueError('Invalid input produced success: ' + name)
            checks.append({'case': name, 'exit': 2, 'fullProcessBytesEqual': True, 'noPartialOutput': True})
    if hashlib.sha256(binary.read_bytes()).hexdigest() != binary_sha:
        raise ValueError('Binary changed during controls')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({'binarySHA256': binary_sha,
        'runnerSHA256': hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
        'checks': checks, 'meaning': __doc__}, indent=2) + '\n')
    print('PASS:', len(checks), 'direct-relation CLI controls; JSON/text/all, complete process bytes twice')


if __name__ == '__main__':
    main()
