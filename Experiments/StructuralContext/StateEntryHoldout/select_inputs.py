"""GET-only metadata selection; never emits or persists source/patch fields."""
import hashlib, json, subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
plan=root/'plan.md'
if not plan.exists(): raise ValueError('Freeze public plan before selection')
if (root/'selection.json').exists(): raise ValueError('Selection already frozen')
excluded={'jordanbaird/Ice':[], 'sindresorhus/KeyboardShortcuts':[]}
def api(endpoint, jq):
 return subprocess.check_output(['gh','api','--method','GET',endpoint,'--jq',jq])
def sha(data):return hashlib.sha256(data).hexdigest()
audit=[]; cases=[]
for repo,prefix in [('jordanbaird/Ice','Ice/'),('sindresorhus/KeyboardShortcuts','Sources/')]:
 rows=api(f'repos/{repo}/pulls?state=closed&sort=created&direction=desc&per_page=40', '.[] | {number,created_at,merged_at,base: .base.sha,head: .head.sha} | @json')
 (root/(repo.split('/')[1].replace('.','-')+'-metadata.jsonl')).write_bytes(rows)
 selected=0
 for row in sorted([json.loads(x) for x in rows.splitlines()],key=lambda x:(x['created_at'],x['number']),reverse=True):
  entry=dict(repository=repo,number=row['number'],createdAt=row['created_at'],mergedAt=row['merged_at'],selected=False)
  audit.append(entry)
  if selected==1:entry['reason']='quota-already-fixed';continue
  if row['number'] in excluded[repo]:entry['reason']='prior-metadata';continue
  if not row['merged_at'] or row['merged_at']>='2026-10-07T00:00:00Z':entry['reason']='not-merged-by-cutoff';continue
  detail=json.loads(api(f"repos/{repo}/pulls/{row['number']}",'{changedFiles:.changed_files,base:.base.sha,head:.head.sha,mergedAt:.merged_at}'))
  if (detail['base'],detail['head'],detail['mergedAt']) != (row['base'],row['head'],row['merged_at']):
   entry['reason']='metadata-changed-stop-repository';break
  # --jq excludes patch payload entirely from returned bytes.
  data=subprocess.check_output(['gh','api','--method','GET','--paginate',f"repos/{repo}/pulls/{row['number']}/files",'--jq','.[] | {filename,previous_filename,status,additions,deletions,changes} | @json'])
  changes=[json.loads(x) for x in data.splitlines()]
  entry['fileMetadataSHA256']=sha(data)
  (root/(repo.split('/')[1].replace('.','-')+'-'+str(row['number'])+'-files.jsonl')).write_bytes(data)
  entry['expectedChangedFiles']=detail['changedFiles']
  entry['receivedChangedFiles']=len(changes)
  if len(changes)!=detail['changedFiles'] or len({f['filename'] for f in changes})!=len(changes):
   entry['reason']='incomplete-files-stop-repository';break
  production=sorted({name for f in changes for name in (f['filename'],f.get('previous_filename')) if name and name.startswith(prefix) and name.endswith('.swift')})
  entry['productionSwift']=production
  if not production:entry['reason']='no-production-swift';continue
  comparison=json.loads(api(f"repos/{repo}/compare/{row['base']}...{row['head']}",'{mergeBase:.merge_base_commit.sha,status:.status}'))
  case=dict(repository=repo,number=row['number'],url=f"https://github.com/{repo}/pull/{row['number']}",before=comparison['mergeBase'],after=row['head'],reportedBase=row['base'],prefix=prefix,changes=changes)
  cases.append(case); entry.update(selected=True,reason='first-eligible-production-swift',comparison=comparison);selected+=1
result=dict(planSHA256=sha(plan.read_bytes()),selectorSHA256=sha(Path(__file__).read_bytes()),excluded=excluded,audit=audit,cases=cases,meaning='Frozen before source, diff or tool-output inspection; no size/title/switch selection')
(root/'selection.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print([(c['repository'],c['number']) for c in cases])
