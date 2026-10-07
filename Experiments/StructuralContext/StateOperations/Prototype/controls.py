"""Own source controls; no external target code executes."""
import argparse,hashlib,json,subprocess,tempfile
from pathlib import Path
p=argparse.ArgumentParser();p.add_argument('--binary',type=Path,required=True)
p.add_argument('--output',type=Path);p.add_argument('--text-output',type=Path)
args=p.parse_args();binary=args.binary.resolve()
rows=[];sample_text=None
def run(name,before,after,expect):
 global sample_text
 with tempfile.TemporaryDirectory(prefix='sekka-state-controls-') as directory:
  root=Path(directory);(root/'before').mkdir();(root/'after').mkdir()
  (root/'before/Example.swift').write_text(before);(root/'after/Example.swift').write_text(after)
  command=[str(binary),str(root/'before'),str(root/'after')]
  a=subprocess.run(command,capture_output=True);b=subprocess.run(command,capture_output=True)
  assert (a.returncode,a.stdout,a.stderr)==(b.returncode,b.stdout,b.stderr),(name,'unstable')
  if expect is None:assert a.returncode==2 and not a.stdout and a.stderr
  else:
   assert a.returncode==0 and not a.stderr,(name,a.stderr)
   expect(json.loads(a.stdout))
  text_runs=[subprocess.run(command+['--text'],capture_output=True) for _ in range(2)]
  ta,tb=text_runs
  assert (ta.returncode,ta.stdout,ta.stderr)==(tb.returncode,tb.stdout,tb.stderr),(name,'unstable text')
  assert ta.returncode==a.returncode and ta.stderr==a.stderr
  if expect is None:assert not ta.stdout
  else:
   assert 'syntax candidates, not design warnings' in ta.stdout.decode() and 'Limits:' in ta.stdout.decode()
   assert str(len(json.loads(a.stdout)['relationships'])) in ta.stdout.decode().splitlines()[1]
   if name=='added-operation-existing-data':sample_text=ta.stdout
  rows.append(dict(case=name,exit=a.returncode,fullProcessBytesEqual=True,textProcessBytesEqual=True))
def one(report):assert len(report['relationships'])==1,report
def zero(report):assert not report['relationships'],report
base='struct Store {\n var state = 0\n func read() -> Int { state }\n}'
run('added-operation-existing-data',base,base[:-1]+' mutating func update() { state += 1 } }',one)
def explicit_self(report):
 one(report);operation=report['relationships'][0]['changedOperations'][0]
 assert {x['form'] for x in operation['references']}=={'explicit-self-written-member','unqualified-binding-unresolved'}
 assert 'state' in operation['shadowCandidates']
run('explicit-self-over-parameter-shadow',base,base[:-1]+' func set(state: Int) { print(self.state, state) } }',explicit_self)
def shadow(report):
 one(report);r=report['relationships'][0]['changedOperations'][0]
 assert 'state' in r['shadowCandidates'] and all(x['form']=='unqualified-binding-unresolved' for x in r['references'])
run('parameter-shadow-remains-unresolved',base,base[:-1]+' func unrelated(state: Int) { print(state) } }',shadow)
run('local-shadow-remains-unresolved',base,base[:-1]+' func unrelated() { let state = 4; print(state) } }',shadow)
run('closure-shadow-remains-unresolved',base,base[:-1]+' func unrelated() { [1].forEach { state in print(state) } } }',shadow)
run('same-name-other-owner',base,base+'\nstruct Other { func unrelated(state: Int) { print(state) } }',zero)
run('arbitrary-receiver-field-not-connected',base,base[:-1]+' func unrelated(other: Store) { print(other.state) } }',zero)
run('nested-type-field-not-connected',base,base[:-1]+' func unrelated() { struct Other { var state = 0; func value() -> Int { state } }; print(Other()) } }',zero)
def no_warning(report):
 one(report)
 def inspect(value):
  if isinstance(value,dict):
   assert 'warning' not in value and 'designVerdict' not in value
   for child in value.values():inspect(child)
  elif isinstance(value,list):
   for child in value:inspect(child)
 inspect(report)
run('legitimate-dedicated-operation-no-warning',base,base[:-1]+' func debug() { print(state) } }',no_warning)
computed='struct Store {\n var state: Int { 1 }\n func read() -> Int { state }\n}'
def accessor(r):one(r);assert r['relationships'][0]['propertyCandidates'][0]['kind']=='accessor; storage-unresolved'
run('computed-property-storage-unresolved',computed,computed[:-1]+' func debug() { print(state) } }',accessor)
run('unchanged-and-comment-only',base,base+' // changed comment\n',zero)
run('extension-not-assumed-same-owner',base,base+'\nextension Store { func debug() { print(state) } }',zero)
run('normal-zero','struct Empty {}','struct Empty {}',zero)
run('parse-failure-not-zero',base,'struct Store {',None)
unchanged_use='struct Store {\n var state = 0\n func read() -> Int { state }\n func debug() { print(state); print(1) }\n}'
run('unrelated-body-edit-does-not-anchor-field',unchanged_use,unchanged_use.replace('print(1)','print(2)'),zero)
existing_changed='struct Store {\n var state = 0\n mutating func update() { state += 1 }\n}'
def changed_helper(report):
 one(report)
 helpers=[op for op in report['relationships'][0]['changedOperations'] if op.get('selector')=='update()']
 assert len(helpers)==1 and helpers[0]['beforeCorrespondence']=='changed' and helpers[0]['changedUsageExpressions']
run('existing-helper-may-change',existing_changed,existing_changed.replace('state += 1','state += 2')[:-1]+'\n func trace() { print(state) } }',changed_helper)
run('repeated-same-use-count-increase',unchanged_use,unchanged_use.replace('print(state);','print(state); print(state);'),one)
run('literal-unicode-names-not-normalized',base.replace('state','caf\u00e9'),base.replace('state','caf\u00e9')[:-1]+' func other() { print(cafe\u0301) } }',zero)
def conditional(r):
 one(r);assert len(r['relationships'][0]['propertyCandidates'])==2
 assert all(p['conditions'] for p in r['relationships'][0]['propertyCandidates'])
conditional_base='struct Store {\n#if FLAG\n var state = 0\n#else\n var state = 1\n#endif\n func read() -> Int { state }\n}'
run('conditional-property-candidates-remain-distinct',conditional_base,conditional_base[:-1]+' func trace() { print(state) } }',conditional)
def observed(r):one(r);assert r['relationships'][0]['propertyCandidates'][0]['kind']=='observed-stored'
observed_base='struct Store {\n var state = 0 { didSet { print(state) } }\n func read() -> Int { state }\n}'
run('observed-property-distinct-from-computed',observed_base,observed_base[:-1]+' func trace() { print(state) } }',observed)
getter_local='struct Store {\n var value: Int { let state = 1; return state }\n}'
run('implicit-getter-local-property-not-invented',getter_local,getter_local[:-1]+' func unrelated(state: Int) { print(state) } }',zero)
getter_func='struct Store {\n var state = 0\n var value: Int { func read() -> Int { state }; return read() }\n}'
def no_local_operations(report):
 one(report);relation=report['relationships'][0]
 assert all(op.get('selector')!='read()' for op in relation['changedOperations']+relation['existingOperations'])
 assert [op['kind'] for op in relation['existingOperations']]==['property-body']
run('implicit-getter-local-function-not-owner-operation',getter_func,getter_func[:-1]+' func trace() { print(state) } }',no_local_operations)
initializer_local='struct Store {\n var value: Int = { let state = 1; return state }()\n}'
run('stored-initializer-closure-local-property-not-invented',initializer_local,initializer_local[:-1]+' func unrelated(state: Int) { print(state) } }',zero)
subscript_local='struct Store {\n subscript(i: Int) -> Int { let state = i; return state }\n}'
run('subscript-local-property-not-invented',subscript_local,subscript_local[:-1]+' func unrelated(state: Int) { print(state) } }',zero)
branch_owners='#if FLAG\n'+base+'\n#else\nstruct Store {\n func value() -> Int { 1 }\n}\n#endif\n'
run('different-conditional-owners-not-joined',branch_owners,branch_owners.replace('func value() -> Int { 1 }','func value() -> Int { 1 }\n func trace(state: Int) { print(state) }'),zero)
duplicate_owners=base+'\nstruct Store {\n func value() -> Int { 1 }\n}'
run('duplicate-owner-header-correspondence-not-assumed',duplicate_owners,duplicate_owners.replace('func value() -> Int { 1 }','func value() -> Int { 1 }\n func trace(state: Int) { print(state) }'),zero)
run('owner-line-shift-keeps-unique-correspondence',base,'\n\n'+base[:-1]+' func trace() { print(state) } }',one)
call_base='struct Store {\n var state = 0\n func read() -> Int { state }\n}\nextension Store {\n func caller() -> Int { read() }\n}'
def extension_call(report):
 one(report)
 existing=report['relationships'][0]['existingOperations']
 calls=[c for op in existing for c in op['writtenCallerCandidates'] if c['caller']['line']==7]
 assert len(calls)==1 and calls[0]['target']['line']==3 and calls[0]['call']['line']==7
 assert calls[0]['ownerRelation']=='same-file-unqualified-extension-name-candidate; owner-unresolved'
 assert calls[0]['meaning']=='same-written-selector; callee-unresolved'
def add_trace(source):return source.replace('\n}', '\n func trace() { print(state) }\n}',1)
run('extension-incoming-call-keeps-candidate-boundary',call_base,add_trace(call_base),extension_call)
def no_extension_calls(report):
 assert all(c['ownerRelation']=='same-lexical-owner' for r in report['relationships'] for op in r['existingOperations']+r['changedOperations'] for c in op['writtenCallerCandidates'])
for label,suffix in [('alias','\ntypealias Store = Int'),('protocol','\nprotocol Store {}'),('duplicate-nominal','\nstruct Store {}')]:
 run('extension-join-rejected-for-'+label,call_base+suffix,add_trace(call_base)+suffix,no_extension_calls)
for label,extended in [('qualified','Other.Store'),('generic','Store<Int>')]:
 source=call_base.replace('extension Store','extension '+extended)
 run('extension-join-rejected-for-'+label,source,add_trace(source),lambda r:(one(r),no_extension_calls(r)))
conditional_extension=call_base.replace('extension Store','\n#if FLAG\nextension Store')+'\n#endif'
def extension_conditions(report):
 one(report)
 calls=[c for op in report['relationships'][0]['existingOperations'] for c in op['writtenCallerCandidates'] if 'extension-name-candidate' in c['ownerRelation']]
 assert len(calls)==1 and calls[0]['conditions'] and '#if FLAG' in calls[0]['conditions'][0]
run('extension-conditions-kept-unresolved',conditional_extension,add_trace(conditional_extension),extension_conditions)
with tempfile.TemporaryDirectory(prefix='sekka-state-errors-') as directory:
 root=Path(directory);folder=root/'input';folder.mkdir();(folder/'file.swift').write_bytes(b'\xff')
 for name,left,right in [('invalid-utf8',folder,folder),('missing-root',root/'missing',folder)]:
  for flags in [[],['--text']]:
   command=[str(binary),str(left),str(right)]+flags;a=subprocess.run(command,capture_output=True);b=subprocess.run(command,capture_output=True)
   assert (a.returncode,a.stdout,a.stderr)==(b.returncode,b.stdout,b.stderr) and a.returncode==2 and not a.stdout and a.stderr
  rows.append(dict(case=name,exit=2,fullProcessBytesEqual=True,textProcessBytesEqual=True))
 (folder/'file.swift').write_text(base);(root/'link').symlink_to(folder,target_is_directory=True)
 for flags in [[],['--text']]:
  command=[str(binary),str(root/'link'),str(folder)]+flags;a=subprocess.run(command,capture_output=True);b=subprocess.run(command,capture_output=True)
  assert (a.returncode,a.stdout,a.stderr)==(b.returncode,b.stdout,b.stderr) and a.returncode==2 and not a.stdout and a.stderr
 rows.append(dict(case='symlink-root-rejected',exit=2,fullProcessBytesEqual=True,textProcessBytesEqual=True))
receipt=json.dumps(dict(binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),runnerSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),controls=rows,scope='Scratch expression and unresolved boundaries, not design or utility'),indent=2)+'\n'
if args.output:
 args.output.parent.mkdir(parents=True,exist_ok=True);args.output.write_text(receipt)
if args.text_output:
 args.text_output.parent.mkdir(parents=True,exist_ok=True);args.text_output.write_bytes(sample_text)
print(receipt,end='')
