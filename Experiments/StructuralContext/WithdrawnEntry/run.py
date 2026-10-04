"""Replay fixed read-only inputs through an own inventory diagnostic, twice."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--binary',type=Path,required=True)
p.add_argument('--input',type=Path,required=True)
p.add_argument('--output',type=Path,required=True)
p.add_argument('--manifest',type=Path,default=Path(__file__).parents[1]/'ResultHoldout/inputs.json')
args=p.parse_args();manifest=json.loads(args.manifest.read_text());binary=args.binary.resolve()
# Validate all selected bytes before running any parser. No target commands are run.
for case in manifest:
    for side in ['before','after']:
        root=args.input/case['id']/side
        if root.is_symlink():raise ValueError('Symlink input root')
        paths=list(root.rglob('*'))
        if any(x.is_symlink() for x in paths):raise ValueError('Symlink in fixed input')
        expected={e['path']:e for e in case['files'] if e['side']==side}
        actual={str(x.relative_to(root)) for x in paths if x.is_file()}
        if actual!=set(expected):raise ValueError('Input inventory differs: '+case['id']+'/'+side)
        for name,e in expected.items():
            data=(root/name).read_bytes()
            blob=hashlib.sha1(('blob %d\0'%len(data)).encode()+data).hexdigest()
            if len(data)!=e['bytes'] or hashlib.sha256(data).hexdigest()!=e['sha256'] or blob!=e['blob']:
                raise ValueError('Input bytes differ: '+case['id']+'/'+side+'/'+name)
args.output.mkdir(parents=True,exist_ok=False);results=[]
for c in manifest:
    command=[str(binary),str(args.input/c['id']/'before'/c['prefix']),str(args.input/c['id']/'after'/c['prefix'])]
    first=subprocess.run(command,capture_output=True);second=subprocess.run(command,capture_output=True)
    if (first.returncode,first.stdout,first.stderr)!=(second.returncode,second.stdout,second.stderr):
        raise ValueError('Unstable complete output: '+c['id'])
    if first.returncode!=0:
        raise ValueError('Diagnostic failed, not a zero result: '+c['id'])
    json.loads(first.stdout)
    (args.output/(c['id']+'.json')).write_bytes(first.stdout)
    (args.output/(c['id']+'.stderr')).write_bytes(first.stderr)
    results.append(dict(case=c['id'],exit=first.returncode,allExitStdoutStderrBytesEqual=True,
        stdoutSHA256=hashlib.sha256(first.stdout).hexdigest(),stderrSHA256=hashlib.sha256(first.stderr).hexdigest()))
    print(c['id']+': complete byte equality',flush=True)
(args.output/'execution.json').write_text(json.dumps(dict(
    binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),runnerSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),
    inputsSHA256=hashlib.sha256(args.manifest.read_bytes()).hexdigest(),validatedEntries=sum(len(c['files']) for c in manifest),results=results),indent=2)+'\n')
