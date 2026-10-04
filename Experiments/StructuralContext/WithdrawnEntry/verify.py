"""Exercise the diagnostic with own Swift examples and unchanged inventory dump."""
import argparse
import copy
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import sys
import tempfile

spec=importlib.util.spec_from_file_location('withdrawn_audit',Path(__file__).with_name('audit.py'))
audit=importlib.util.module_from_spec(spec); spec.loader.exec_module(audit)


def check(binary, root, before, after):
    for side,files in [('before',before),('after',after)]:
        folder=root/side;folder.mkdir()
        for name,text in files.items():
            path=folder/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
    cmd=[str(binary),str(root/'before'),str(root/'after')]
    a=subprocess.run(cmd,capture_output=True);b=subprocess.run(cmd,capture_output=True)
    if (a.returncode,a.stdout,a.stderr)!=(b.returncode,b.stdout,b.stderr) or a.returncode!=0:
        raise ValueError('Unstable or failed valid diagnostic: '+str(root.name))
    return audit.analyze(root.name,json.loads(a.stdout),'',[])


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--binary',type=Path,required=True);p.add_argument('--output',type=Path,required=True);args=p.parse_args()
    binary=args.binary.resolve(); passed=[]
    helper='struct Helper { func copy(into target: Int) {} }\n'
    caller='func old(_ h: Helper) { h.copy(into: 1) }\n'
    sdk='struct SDK { func copy(into target: Int) {} }\nfunc old(_ h: Helper) { h.copy(into: 1) }\n'
    cases=[
        ('deleted-caller',{'H.swift':helper+caller},{'H.swift':helper},'retained-token-identical-candidate','no-key-counterpart-no-same-selector'),
        ('moved-call-not-decrease',{'H.swift':helper,'Old.swift':caller},{'H.swift':helper,'New.swift':caller},None,None),
        ('renamed-caller-remains-unknown',{'H.swift':helper+caller},{'H.swift':helper+'func renamed(_ h: Helper) {}'},'retained-token-identical-candidate','no-key-counterpart-no-same-selector'),
        ('signature-change-remains-unknown',{'H.swift':helper+caller},{'H.swift':helper+'func old(_ h: Helper?) {}'},'retained-token-identical-candidate','no-key-counterpart-same-selector-remains'),
        ('added-argument-remains-unknown',{'H.swift':helper+caller},{'H.swift':helper+'func old(_ h: Helper, count: Int) {}'},'retained-token-identical-candidate','no-key-counterpart-no-same-selector'),
        ('same-name-sdk-is-not-resolved',{'H.swift':sdk},{'H.swift':'struct SDK { func copy(into target: Int) {} }'},'retained-token-identical-candidate','no-key-counterpart-no-same-selector'),
        ('helper-deleted',{'H.swift':helper+caller},{'H.swift':''},'same-selector-declaration-not-unique',None),
        ('helper-body-changed',{'H.swift':helper+caller},{'H.swift':'struct Helper { func copy(into target: Int) { print(target) } }'},'target-declaration-changed',None),
        ('helper-moved',{'H.swift':helper+caller},{'New.swift':helper},'target-correspondence-changed',None),
        ('conditional-header-changed',{'H.swift':'#if FLAG\n'+helper+'#endif\n'+caller},{'H.swift':'#if OTHER\n'+helper+'#endif'},'target-correspondence-changed',None),
        ('ancestor-header-changed',{'H.swift':helper+caller},{'H.swift':helper.replace('struct Helper','struct Helper<T>')},'target-header-changed',None),
        ('preceding-else-condition-changed',{'H.swift':'#if FLAG\n#else\n'+helper+'#endif\n'+caller},{'H.swift':'#if OTHER\n#else\n'+helper+'#endif'},'target-correspondence-changed',None),
        ('declaration-without-body',{'H.swift':'protocol Helper { func copy(into target: Int) }\n'+caller},{'H.swift':'protocol Helper { func copy(into target: Int) }'},'declaration-without-body',None),
        ('false-branch-counted-not-active',{'H.swift':helper+'#if false\n'+caller+'#endif'},{'H.swift':helper},'retained-token-identical-candidate',None),
        ('ambiguous-target',{'H.swift':helper+helper+caller},{'H.swift':helper+helper},'same-selector-declaration-not-unique',None),
        ('overload-labels-not-unique',{'H.swift':helper+helper.replace('target: Int','target: String')+caller},{'H.swift':helper+helper.replace('target: Int','target: String')},'same-selector-declaration-not-unique',None),
        ('body-boundary',{'H.swift':helper+'func old(_ h: Helper = Helper()) { func local(_ h: Helper) { h.copy(into: 1) }; struct Local { var h = Helper() } }'},{'H.swift':helper},None,None),
        ('trailing-closure-outside-written-index',{'H.swift':'func copy(into x: ()->Void) {}\nfunc old() { copy { } }'},{'H.swift':'func copy(into x: ()->Void) {}'},None,None),
        ('specialized-call-outside-written-index',{'H.swift':'func copy<T>(into x: T) {}\nfunc old() { copy<Int>(into: 1) }'},{'H.swift':'func copy<T>(into x: T) {}'},None,None),
        ('member-to-unqualified-is-not-decrease',{'H.swift':helper+caller},{'H.swift':helper+'func old(_ h: Helper) { copy(into: 1) }'},None,None),
        ('zero-identical-input',{'H.swift':helper},{'H.swift':helper},None,None),
    ]
    with tempfile.TemporaryDirectory(prefix='sekka-withdrawn-check-') as temp:
        root=Path(temp)
        for name,b,a,expected,state in cases:
            case=root/name;case.mkdir();r=check(binary,case,b,a)
            groups=[g for g in r['decreasedGroups'] if g['selector']=='copy(into:)']
            if expected is None:
                assert not groups,(name,groups)
            else:
                assert len(groups)==1 and groups[0]['status']==expected,(name,groups)
                if state: assert groups[0]['beforeOccurrences'][0]['callerState']==state,(name,groups)
            if name=='false-branch-counted-not-active':
                assert groups[0]['beforeOccurrences'][0]['conditionPositions'][0]['selected']['keyword']=='#if'
            if name=='body-boundary':
                assert not r['decreasedGroups'],r['decreasedGroups']
            if name=='trailing-closure-outside-written-index':
                assert r['formatCounts']['before']['allASTTrailing']==1
            passed.append(name)
        for name,kind in [('malformed','parse'),('non-utf8','read'),('symlink','symlink'),('missing-directory','read')]:
            case=root/name;case.mkdir();before=case/'before';after=case/'after';before.mkdir();after.mkdir()
            (before/'Good.swift').write_text(helper)
            if kind=='parse':(after/'Bad.swift').write_text('func {')
            elif name=='non-utf8':(after/'Bad.swift').write_bytes(b'\xff')
            elif kind=='symlink':(after/'Bad.swift').symlink_to(before/'Good.swift')
            else:after.rmdir()
            cmd=[str(binary),str(before),str(after)];a=subprocess.run(cmd,capture_output=True);b=subprocess.run(cmd,capture_output=True)
            assert (a.returncode,a.stdout,a.stderr)==(b.returncode,b.stdout,b.stderr),(name,a.returncode,a.stderr,b.returncode,b.stderr)
            assert a.returncode==2 and not a.stdout and a.stderr,(name,a)
            passed.append(name+'-rejects-partial-success')
        # The audit must not turn a partial/corrupted replay into a successful report.
        index=root/'receipt-index';index.mkdir();folder=root/'zero-identical-input'
        raw=subprocess.run([str(binary),str(folder/'before'),str(folder/'after')],capture_output=True,check=True)
        (index/'receipt-case.json').write_bytes(raw.stdout);(index/'receipt-case.stderr').write_bytes(raw.stderr)
        manifest=root/'manifest.json';manifest.write_text(json.dumps([dict(id='receipt-case',prefix='',files=[])]))
        needs=root/'needs.json';needs.write_text(json.dumps(dict(needs=[])))
        base=dict(inputsSHA256=hashlib.sha256(manifest.read_bytes()).hexdigest(),binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),
            runnerSHA256=hashlib.sha256(Path(__file__).with_name('run.py').read_bytes()).hexdigest(),validatedEntries=0,
            results=[dict(case='receipt-case',exit=0,allExitStdoutStderrBytesEqual=True,
                stdoutSHA256=hashlib.sha256(raw.stdout).hexdigest(),stderrSHA256=hashlib.sha256(raw.stderr).hexdigest())])
        changes=[('complete-receipt',None,None),('missing-receipt',None,None),('wrong-manifest','inputsSHA256','bad'),
            ('wrong-binary','binarySHA256','bad'),('wrong-runner','runnerSHA256','bad'),('wrong-input-count','validatedEntries',1),
            ('missing-case','results',[]),('duplicate-case','results',base['results']*2),
            ('failed-case','exit',2),('unstable-case','allExitStdoutStderrBytesEqual',False),
            ('wrong-stdout','stdoutSHA256','bad'),('wrong-stderr','stderrSHA256','bad')]
        for name,key,value in changes:
            receipt=copy.deepcopy(base)
            if key in ('exit','allExitStdoutStderrBytesEqual','stdoutSHA256','stderrSHA256'):receipt['results'][0][key]=value
            elif key:receipt[key]=value
            path=index/'execution.json'
            if name=='missing-receipt':path.unlink()
            else:path.write_text(json.dumps(receipt))
            output=root/(name+'.json')
            command=[sys.executable,str(Path(__file__).with_name('audit.py')),'--binary',str(binary),'--index',str(index),
                '--manifest',str(manifest),'--needs',str(needs),'--output',str(output)]
            a=subprocess.run(command,capture_output=True);b=subprocess.run(command,capture_output=True)
            assert (a.returncode,a.stdout,a.stderr)==(b.returncode,b.stdout,b.stderr),(name,a,b)
            if name=='complete-receipt':assert a.returncode==0 and output.exists()
            else:assert a.returncode!=0 and not a.stdout and not output.exists(),(name,a)
            passed.append(name)
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(dict(binarySHA256=hashlib.sha256(binary.read_bytes()).hexdigest(),
        auditSHA256=hashlib.sha256(Path(__file__).with_name('audit.py').read_bytes()).hexdigest(),checks=passed,
        meaning='Own syntax controls; SDK same-name remains unresolved, not an asserted dependency or useful relation.'),indent=2)+'\n')
    print('PASS: %d withdrawn-entry syntax/zero/error controls, complete exit/stdout/stderr twice'%len(passed))


if __name__=='__main__':main()
