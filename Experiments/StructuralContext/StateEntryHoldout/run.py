import hashlib,json,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parent
sha=lambda data:hashlib.sha256(data).hexdigest()
freeze=json.loads((root/'freeze.json').read_text());binary=root/'state-probe'
assert sha(binary.read_bytes())==freeze['binarySHA256']
source=Path('Experiments/StructuralContext/StateOperations/Prototype/Sources/state-probe/main.swift')
assert sha(source.read_bytes())==freeze['sourceSHA256']
manifest=json.loads((root/'inputs.json').read_text())
validation=json.loads((root/'input-validation.json').read_text())
assert {c['id'] for c in manifest}=={c['case'] for c in validation['cases']}
output=root/'replay';output.mkdir(exist_ok=False)
results=[]
for case in manifest:
 row=dict(case=case['id'],formats={})
 for name,flags in [('json',[]),('text',['--text'])]:
  packet=root/'packet'/case['id'];left=packet/'before'/case['prefix'];right=packet/'after'/case['prefix']
  left.mkdir(parents=True,exist_ok=True);right.mkdir(parents=True,exist_ok=True)
  runs=[];seconds=[]
  for _ in range(2):
   start=time.monotonic();runs.append(subprocess.run([str(binary.resolve()),str(left),str(right)]+flags,capture_output=True));seconds.append(time.monotonic()-start)
  a,b=runs
  assert (a.returncode,a.stdout,a.stderr)==(b.returncode,b.stdout,b.stderr)
  (output/(case['id']+'.'+name)).write_bytes(a.stdout);(output/(case['id']+'.'+name+'.stderr')).write_bytes(a.stderr)
  row['formats'][name]=dict(exit=a.returncode,stdoutSHA256=sha(a.stdout),stderrSHA256=sha(a.stderr),fullProcessBytesEqual=True,bytes=len(a.stdout),lines=len(a.stdout.splitlines()),seconds=seconds)
  if name=='json':
   if a.returncode==0:
    assert not a.stderr;report=json.loads(a.stdout);row.update(relationships=len(report['relationships']),files=[report['beforeFiles'],report['afterFiles']],beforeInputSHA256=report['beforeInputSHA256'],afterInputSHA256=report['afterInputSHA256'])
   else:assert a.returncode==2 and not a.stdout and a.stderr;row['meaning']='input/parse failure, not zero'
 assert row['formats']['json']['exit']==row['formats']['text']['exit']
 results.append(row);print(case['id'],row.get('relationships','failed'),flush=True)
assert sha(binary.read_bytes())==freeze['binarySHA256'] and sha(source.read_bytes())==freeze['sourceSHA256']
receipt=dict(binarySHA256=freeze['binarySHA256'],sourceSHA256=freeze['sourceSHA256'],inputsManifestSHA256=sha((root/'inputs.json').read_bytes()),runnerSHA256=sha(Path(__file__).read_bytes()),scope='New frozen inputs; process bytes are not utility evidence',results=results)
(output/'execution.json').write_text(json.dumps(receipt,indent=2)+'\n')
