"""Exercise opt-in review on own source through the actual Git/directory CLI paths."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile

binary = str(Path(sys.argv[1]).resolve())
fixtures = Path(__file__).resolve().parent.parent / 'Experiments/DependencyRelay/ContractFixtures'
before = (fixtures / 'before/Example.swift').read_text()
after = (fixtures / 'after/Example.swift').read_text()
with tempfile.TemporaryDirectory(prefix='sekka-review-trial-') as temp:
    repo = Path(temp)
    def git(*args):
        return subprocess.check_output(['git', '-c', 'user.name=Sekka Tests', '-c', 'user.email=tests@example.invalid', '-c', 'commit.gpgsign=false', *args], cwd=repo, stderr=subprocess.PIPE).decode().strip()
    def run(*args, code=0):
        command = [binary, 'review', *args]
        a = subprocess.run(command, cwd=repo, capture_output=True, timeout=20)
        b = subprocess.run(command, cwd=repo, capture_output=True, timeout=20)
        assert (a.returncode, a.stdout, a.stderr) == (b.returncode, b.stdout, b.stderr)
        assert a.returncode == code, (command, a.stdout, a.stderr)
        if code==2:
            assert not a.stdout and a.stderr
        return a.stdout.decode()
    git('init', '-b', 'main')
    (repo / '.gitignore').write_text('Ignored.swift\n')
    (repo / 'Example.swift').write_text(before)
    (repo / 'README.md').write_text('Before\n')
    git('add', '.'); git('commit', '-m', 'before')
    base=git('rev-parse', 'HEAD')
    (repo / 'Example.swift').write_text(after)
    (repo / 'README.md').write_text('After\n')
    (repo / 'Ignored.swift').write_text('invalid {{{')
    working=json.loads(run(base, '--format', 'json'))
    assert working['analysis']=='experimental-callback-contracts'
    change,=working['contract']['changes']
    assert len(change['adaptations'])==3
    assert {c['file'] for c in working['inventory']['changes']}=={'Example.swift','README.md'}
    assert 'zero is not design approval' in run(base)
    run(base, '--fail-on-findings', code=1)
    run(base, '--format', 'github', code=2)
    run(base, '--json-detail', 'full', '--format', 'json', code=2)
    run(base, '--show-diff', 'Example.swift', code=2)
    run(base, '--before', str(fixtures/'before'), '--after', str(fixtures/'after'), code=2)
    git('update-index', '--assume-unchanged', 'Example.swift')
    hidden=json.loads(run(base, '--format', 'json'))
    assert hidden['contract']==working['contract']
    assert {c['file'] for c in hidden['inventory']['changes']}=={'Example.swift','README.md'}
    git('update-index', '--no-assume-unchanged', 'Example.swift')
    git('add','Example.swift','README.md'); git('commit','-m','after')
    head=git('rev-parse','HEAD')
    fixed=json.loads(run(base, '--head', head, '--format', 'json'))
    assert fixed['contract']==working['contract']
    unchanged=json.loads(run(head, '--head', head, '--format', 'json'))
    assert not unchanged['contract']['changes']
    directory=json.loads(run('--before', str(fixtures/'before'), '--after', str(fixtures/'after'), '--format','json'))
    assert directory['contract']==fixed['contract']
    (repo/'Bad.swift').write_text('struct Broken {')
    run(base, code=2)
    (repo/'Bad.swift').unlink()
    (repo/'Example.swift').write_bytes(b'\xef\xbb\xbf' + after.encode())
    run(base, code=2)
    git('add','Example.swift'); git('commit','-m','BOM')
    run(base, '--head', 'HEAD', code=2)
    (repo/'Example.swift').write_bytes(b' ' * 4_000_001)
    run(base, code=2)
    git('add','Example.swift'); git('commit','-m','oversized')
    run(base, '--head', 'HEAD', code=2)
    # An empty Swift side is valid in the real diff input; entirely new APIs cannot be paired.
    git('rm','Example.swift'); git('commit','-m','remove source')
    removed=json.loads(run(head,'--head','HEAD','--format','json'))
    assert not removed['contract']['changes'] and removed['contract']['afterFiles']==[]
    (repo/'Example.swift').write_text('\n'.join('struct T%d {}'%i for i in range(3)))
    for i in range(128): (repo/f'Added{i}.swift').write_text(f'struct A{i} {{}}')
    run(head,code=2)
    print('PASS: real Git working tree/committed/unchanged/empty side, directory parity, parse/cap/argument failures; all outputs repeated byte-for-byte')
