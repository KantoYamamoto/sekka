"""Build the diagnostic in an own-source temporary copy and check syntax boundaries."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import shutil
import subprocess
import tarfile
import tempfile

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--scratch', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
args = p.parse_args()
repo = Path(__file__).resolve().parents[3]
head = subprocess.check_output(['git', '-C', str(repo), 'rev-parse', 'HEAD']).decode().strip()
with tempfile.TemporaryDirectory(prefix='sekka-index-check-') as directory:
    root = Path(directory)
    data = subprocess.check_output(['git', '-C', str(repo), 'archive', head, 'Experiments/StructuralContext'])
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        for member in archive.getmembers():
            if member.name.startswith('/') or '..' in Path(member.name).parts or not (member.isfile() or member.isdir()):
                raise ValueError('Unsupported own archive entry: ' + member.name)
        archive.extractall(str(root))
    package = root / 'Experiments/StructuralContext'
    main = package / 'Sources/context-probe/main.swift'
    original = main.read_text()
    if original.count('\ndo {') != 1:
        raise ValueError('Source reader/entry boundary changed; review diagnostic composition')
    body = (package / 'Diagnostics/inventory-body.swift').read_text()
    main.write_text(original.split('\ndo {', 1)[0] + '\n' + body)
    build = ['swift', 'build', '--package-path', str(package), '--scratch-path', str(args.scratch.resolve())]
    subprocess.run(build, check=True)
    bin_path = subprocess.check_output(build + ['--show-bin-path']).decode().strip()
    binary = Path(bin_path) / 'context-probe'
    args.output.parent.mkdir(parents=True, exist_ok=True)
    # Freeze this own diagnostic for the read-only manifest replay; output is not source control.
    frozen = args.output.with_name('inventory-probe')
    shutil.copyfile(binary, frozen); frozen.chmod(0o700)
    before = root / 'before'; after = root / 'after'; before.mkdir(); after.mkdir()
    source = '''struct ResultBag {}
func make() -> (ResultBag, Int) { (ResultBag(), 1) }
func generic<T>() -> T { T() }
func configured(_ value: ResultBag = ResultBag()) -> ResultBag {
  struct Local { var result = ResultBag() }
  return ResultBag()
}'''
    for folder in [before, after]:
        (folder / 'Valid.swift').write_text(source)
    command = [str(frozen.resolve()), str(before), str(after)]
    a = subprocess.run(command, capture_output=True); b = subprocess.run(command, capture_output=True)
    if a.returncode != 0 or (a.returncode, a.stdout, a.stderr) != (b.returncode, b.stdout, b.stderr):
        raise ValueError('Diagnostic parse/bytes unstable')
    calls = json.loads(a.stdout)['after']['calls']
    if not any(c['selector'] == 'ResultBag()' and c['callerReturnNames'] == ['Int', 'ResultBag'] and c['caller']['line'] == 2 for c in calls):
        raise ValueError('Tuple return/name position mismatch')
    if not any(c['selector'] == 'T()' and c['callerReturnNames'] == ['T'] for c in calls):
        raise ValueError('Generic spelling was changed into a resolved type')
    configured = [c for c in calls if c.get('caller') and c['caller']['line'] == 4 and c['selector'] == 'ResultBag()']
    if [c['callerBodyOwned'] for c in configured] != [False, False, True]:
        raise ValueError('Header/local-type calls were attributed to the body')
    (after / 'Bad.swift').write_text('func {')
    bad = subprocess.run(command, capture_output=True)
    if bad.returncode != 2 or bad.stdout:
        raise ValueError('Malformed input produced partial output')
    args.output.write_text(json.dumps({'head': head, 'diagnosticBodySHA256': hashlib.sha256(body.encode()).hexdigest(),
        'binarySHA256': hashlib.sha256(frozen.read_bytes()).hexdigest(),
        'checks': ['own tracked-source archive', 'stable JSON/exit/stderr', 'tuple return names and caller position',
                   'generic spelling remains syntax', 'body excludes default/header and local-type calls', 'malformed input rejects partial output'],
        'meaning': 'Diagnostic syntax facts only. No target code execution or design conclusion.'}, indent=2) + '\n')
print('PASS: inventory diagnostic syntax and input boundary checks')
