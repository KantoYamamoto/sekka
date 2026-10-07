"""Run fixed all-detail modes twice; runtime does not measure review time."""
import concurrent.futures,hashlib,json,subprocess,time
from pathlib import Path
root=Path(__file__).resolve().parent;binary=root.parent/'direct-relations/relations-probe-text-state'
def sha(data):return hashlib.sha256(data).hexdigest()
expected='c71d9882616173e152050efabf41f962ae78d07ccac11963692055b6db094f7a'
assert sha(binary.read_bytes())==expected
cases=json.loads((root/'inputs.json').read_text())
assert {c['id'] for c in cases}=={c['case'] for c in json.loads((root/'input-validation.json').read_text())['cases']}
def run(job):
 case,mode,suffix=job;packet=root/'packet'/case['id'];command=[str(binary.resolve()),str(packet/'before'/case['prefix']),str(packet/'after'/case['prefix'])]+mode
 runs=[];durations=[]
 for i in range(2):
  started=time.monotonic();r=subprocess.run(command,capture_output=True);durations.append(time.monotonic()-started);runs.append(r)
 a,b=runs;assert (a.returncode,a.stdout,a.stderr)==(b.returncode,b.stdout,b.stderr);assert not a.returncode and not a.stderr
 (root/'replay'/(case['id']+'.'+suffix)).write_bytes(a.stdout)
 return dict(case=case['id'],mode=suffix,exit=a.returncode,fullProcessBytesEqual=True,stdoutSHA256=sha(a.stdout),stderrSHA256=sha(a.stderr),stdoutBytes=len(a.stdout),seconds=durations)
jobs=[(c,mode,suffix) for c in cases for mode,suffix in [(['--all'],'all.json'),(['--all','--text'],'all.text')]]
with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
 results=[]
 for result in pool.map(run,jobs):results.append(result);print(result['case'],result['mode'],'verified twice',flush=True)
assert sha(binary.read_bytes())==expected
(root/'all-modes.json').write_text(json.dumps(dict(binarySHA256=expected,runnerSHA256=sha(Path(__file__).read_bytes()),results=results,meaning='All-detail modes checked twice; two concurrent jobs, debug binary; process time is not review time'),indent=2)+'\n')
