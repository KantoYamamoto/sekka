"""Prepare equal ordinary-diff packets and frozen direct-output B supplements."""
import argparse,hashlib,json,re,shutil,subprocess
from pathlib import Path
root=Path(__file__).resolve().parent
p=argparse.ArgumentParser();p.add_argument('--case',required=True);p.add_argument('--group',choices=['A','B','both'],default='both');args=p.parse_args()
cases=json.loads((root/'inputs.json').read_text());validation=json.loads((root/'input-validation.json').read_text())
assert {c['id'] for c in cases}=={c['case'] for c in validation['cases']}
binary=root.parent/'direct-relations/relations-probe-text-state'
expected='c71d9882616173e152050efabf41f962ae78d07ccac11963692055b6db094f7a'
def sha(data):return hashlib.sha256(data).hexdigest()
assert sha(binary.read_bytes())==expected
materials=[];all_modes=[]
for case in cases:
 if case['id']!=args.case:continue
 packet=root/'packet'/case['id'];data=(packet/'ordinary.diff').read_bytes();assert sha(data)==case['diffSHA256']
 markers=list(re.finditer(rb'^diff --git .+\n',data,re.M));assert markers and markers[0].start()==0
 swift_headers={('diff --git a/'+c.get('previous_filename',c['filename'])+' b/'+c['filename']+'\n').encode() for c in case['changes'] if c['filename'].endswith('.swift') or c.get('previous_filename','').endswith('.swift')}
 swift_diff=b''.join(data[m.start():markers[i+1].start() if i+1<len(markers) else len(data)] for i,m in enumerate(markers) if m.group() in swift_headers)
 assert {m.group() for m in markers if m.group() in swift_headers}==swift_headers
 row=dict(case=case['id'],prContextSHA256=case['prContextSHA256'],ordinarySwiftDiffSHA256=sha(swift_diff),ordinarySwiftDiffBytes=len(swift_diff),groups={})
 for group in (('A','B') if args.group=='both' else (args.group,)):
  dest=root/'review-material'/case['id']/group;dest.mkdir(parents=True,exist_ok=False)
  (dest/'pr-context.md').write_bytes((packet/'pr-context.md').read_bytes());(dest/'ordinary-swift.diff').write_bytes(swift_diff)
  row['groups'][group]={p.name:sha(p.read_bytes()) for p in dest.iterdir() if p.is_file()}
  if group=='B':
   (dest/'relations.json').write_bytes((root/'replay'/(case['id']+'.stdout')).read_bytes());(dest/'relations.text').write_bytes((root/'replay'/(case['id']+'.text')).read_bytes())
   row['groups'][group].update({p.name:sha(p.read_bytes()) for p in dest.iterdir() if p.is_file()})
 if len(row['groups'])==2:
  assert row['groups']['A']['pr-context.md']==row['groups']['B']['pr-context.md']
  assert row['groups']['A']['ordinary-swift.diff']==row['groups']['B']['ordinary-swift.diff']
 materials.append(row)
assert sha(binary.read_bytes())==expected
(root/('review-material-'+args.case+'-'+args.group+'.json')).write_text(json.dumps(dict(binarySHA256=expected,inputsSHA256=sha((root/'inputs.json').read_bytes()),preparerSHA256=sha(Path(__file__).read_bytes()),materials=materials),indent=2)+'\n')
print([(m['case'],m['ordinarySwiftDiffBytes']) for m in materials])
