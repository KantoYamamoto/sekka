"""Read-only frozen PR material; tree/blob bound archives, no target execution."""
import hashlib, io, json, subprocess, tarfile
from pathlib import Path, PurePosixPath

root = Path(__file__).resolve().parent
selection_path = root / 'selection.json'
selection = json.loads(selection_path.read_text())
packet = root / 'packet'; packet.mkdir(exist_ok=True)
manifest = json.loads((root/'inputs.json').read_text()) if (root/'inputs.json').exists() else []
outcomes = []
def raw(endpoint, accept=None):
    command = ['gh', 'api', '--method', 'GET', endpoint]
    if accept: command += ['-H', 'Accept: ' + accept]
    return subprocess.check_output(command)
for case in selection['cases']:
    repo = case['repository']; cid = repo.split('/')[1].replace('.', '-') + '-' + str(case['number'])
    if any(item['id']==cid for item in manifest):
        outcomes.append(dict(case=cid,status='acquired'))
        continue
    dest = packet / cid; dest.mkdir(exist_ok=True)
    if any(dest.iterdir()): raise ValueError('Partial material exists; inspect before retry: '+cid)
    item = {k:case[k] for k in ['repository','number','url','before','after','prefix']}
    item.update(id=cid, files=[])
    # Validate the selected base before retrieving any patch or source bytes.
    comparison = json.loads(subprocess.check_output(['gh','api','--method','GET',
        f"repos/{repo}/compare/{case['before']}...{case['after']}", '--jq',
        '{mergeBase: .merge_base_commit.sha, status: .status}']))
    if comparison['mergeBase'] != case['before']:
        outcomes.append(dict(case=cid,status='invalid-frozen-base',before=case['before'],
            observedMergeBase=comparison['mergeBase'],comparisonStatus=comparison['status'],
            meaning='Not a zero result; no source/diff/query/review, no replacement or changed ref'))
        (root/'acquisition-outcomes.json').write_text(json.dumps(outcomes,indent=2)+'\n')
        print(cid, 'invalid frozen base; not zero; no replacement',flush=True)
        continue
    item['comparison'] = comparison
    pr = json.loads(raw(f"repos/{repo}/pulls/{case['number']}"))
    (dest / 'pr-context.md').write_text(pr['title'] + '\n\n' + (pr['body'] or '') + '\n')
    if pr['head']['sha'] != case['after'] or pr['base']['sha'] != case['reportedBase']:
        raise ValueError('PR refs changed after selection; no replacement or ref repair')
    changes = case['changes']
    for c in changes:
        if c.get('previous_filename') is None: c.pop('previous_filename',None)
    item['changes'] = changes
    diff = raw(f"repos/{repo}/compare/{case['before']}...{case['after']}", 'application/vnd.github.diff')
    (dest / 'ordinary.diff').write_bytes(diff)
    item['diffSHA256'] = hashlib.sha256(diff).hexdigest()
    item['prContextSHA256'] = hashlib.sha256((dest/'pr-context.md').read_bytes()).hexdigest()
    changed = {f['filename'] for f in changes} | {f['previous_filename'] for f in changes if 'previous_filename' in f}
    for side in ['before','after']:
        ref = case[side]
        tree = json.loads(raw(f'repos/{repo}/git/trees/{ref}?recursive=1'))
        if tree.get('truncated'): raise ValueError('Truncated tree: ' + cid)
        wanted = {e['path']:e for e in tree['tree'] if e['path'] in changed or
            e['path'] in ('LICENSE','LICENSE.md','LICENSE.txt') or
            (e['path'].startswith(case['prefix']) and e['path'].endswith('.swift'))}
        if any(e['type'] != 'blob' or e['mode'] not in ('100644','100755') for e in wanted.values()):
            raise ValueError('Unsupported selected entry: ' + cid)
        archive = raw(f'repos/{repo}/tarball/{ref}')
        if len(archive) > 100_000_000: raise ValueError('Archive budget exceeded; no replacement')
        found = set()
        with tarfile.open(fileobj=io.BytesIO(archive),mode='r:gz') as tf:
            for member in tf:
                name = '/'.join(PurePosixPath(member.name).parts[1:])
                if name not in wanted: continue
                path = PurePosixPath(name)
                if name in found or not member.isfile() or member.size > 20_000_000 or path.is_absolute() or '..' in path.parts:
                    raise ValueError('Unsafe selected archive entry')
                data = tf.extractfile(member).read()
                blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
                if blob != wanted[name]['sha']: raise ValueError('Tree/blob mismatch')
                target = dest / side / name; target.parent.mkdir(parents=True,exist_ok=True); target.write_bytes(data)
                item['files'].append(dict(side=side,path=name,blob=blob,bytes=len(data),
                    sha256=hashlib.sha256(data).hexdigest(),mode=wanted[name]['mode']))
                found.add(name)
        if found != set(wanted): raise ValueError('Missing selected source')
    item['files'].sort(key=lambda f:(f['side'],f['path']))
    manifest.append(item)
    outcomes.append(dict(case=cid,status='acquired'))
    (root / 'inputs.json').write_text(json.dumps(manifest,indent=2)+'\n')
    (root/'acquisition-outcomes.json').write_text(json.dumps(outcomes,indent=2)+'\n')
    print(cid, len(item['files']), 'verified entries',len(diff),'diff bytes',flush=True)
(root / 'materialization-complete.json').write_text(json.dumps(dict(selectedCases=len(selection['cases']),acquiredCases=len(manifest),outcomes=outcomes,
    selectionSHA256=hashlib.sha256(selection_path.read_bytes()).hexdigest(),
    materializerSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest()))+'\n')
