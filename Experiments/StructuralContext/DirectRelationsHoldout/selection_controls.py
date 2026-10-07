"""Exercise selection without network/source reads; own synthetic metadata only."""
import contextlib, hashlib, io, json, runpy, shutil, subprocess, tempfile
from pathlib import Path
from unittest.mock import patch
selector=Path(__file__).with_name('select_inputs.py')
results=[]
def run(case,changes,expected_count,reason=None,alter=False):
 with tempfile.TemporaryDirectory(prefix='sekka-selection-controls-') as folder:
  root=Path(folder);shutil.copyfile(selector,root/'select_inputs.py');(root/'plan.md').write_text('synthetic selection control\n')
  calls=[]
  def fake(command):
   assert command[:4]==['gh','api','--method','GET']
   endpoint=command[4] if command[4]!='--paginate' else command[5]
   calls.append(endpoint)
   if '?state=closed' in endpoint:
    if not endpoint.startswith('repos/apple/'): return b''
    rows=[dict(number=900,created_at='2026-10-01T00:00:00Z',merged_at='2026-10-02T00:00:00Z',base='base',head='head'),dict(number=899,created_at='2026-09-30T00:00:00Z',merged_at='2026-10-01T00:00:00Z',base='base',head='head')]
    return b'\n'.join(json.dumps(r).encode() for r in rows)
   if endpoint.endswith('/files'):return b'\n'.join(json.dumps(r).encode() for r in changes)
   if '/pulls/' in endpoint:return json.dumps(dict(changedFiles=expected_count,base='altered' if alter else 'base',head='head',mergedAt='2026-10-02T00:00:00Z' if endpoint.endswith('/900') else '2026-10-01T00:00:00Z')).encode()
   if '/compare/' in endpoint:return b'{"mergeBase":"ancestor","status":"ahead"}'
   raise AssertionError(endpoint)
  with patch.object(subprocess,'check_output',fake),contextlib.redirect_stdout(io.StringIO()):runpy.run_path(str(root/'select_inputs.py'),run_name='__main__')
  result=json.loads((root/'selection.json').read_text())
  first=result['audit'][0]
  if reason:
   assert first['reason']==reason,(case,first)
   assert not result['cases']
   assert not any('/899' in c for c in calls)
  else:
   assert first['selected']
   assert all(c['before']=='ancestor' and c['reportedBase']=='base' for c in result['cases'])
  results.append(dict(case=case,passed=True))
run('rename-out-remains-eligible',[dict(filename='Elsewhere/file.swift',previous_filename='Sources/file.swift')],1)
run('removed-production-remains-eligible',[dict(filename='Sources/deleted.swift',status='removed')],1)
run('incomplete-file-count-stops',[dict(filename='README.md')],2,'incomplete-files-stop-repository')
run('duplicate-file-inventory-stops',[dict(filename='README.md'),dict(filename='README.md')],2,'incomplete-files-stop-repository')
run('changed-metadata-stops',[],0,'metadata-changed-stop-repository',alter=True)
print(json.dumps(dict(selectorSHA256=hashlib.sha256(selector.read_bytes()).hexdigest(),controls=results,meaning='Own fake metadata, no API/source/selection execution'),indent=2))
