"""Known-input syntax diagnostic. Never resolves receivers, callees or migrations."""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=False).encode()).hexdigest()


def grouped(functions, key):
    result = defaultdict(list)
    for f in functions:
        result[f['declaration'][key]].append(f)
    return result


def intersects(site, file, span):
    return site['file'] == file and site['line'] <= span[1] and span[0] <= site['endLine']


def position(site):
    return {k:site[k] for k in ('file', 'line', 'endLine')}


def condition_fact(branch):
    def directive(d):
        return dict(keyword=d['keyword'],site=position(d['site']),conditionSHA256=digest(d.get('condition')))
    return dict(selected=directive(branch['selected']),preceding=[directive(d) for d in branch['preceding']])


def function_fact(f):
    d = f['declaration']
    return dict(site=position(d['site']), selector=d['selector'], scopeKind=d['scopeKind'],
                declarationSHA256=digest(d['declarationTokens']),
                lexicalHeadersSHA256=digest(d['lexicalScopeHeaders']),
                conditionalPathSHA256=digest(d['conditionalPath']),
                bodyPresent=d.get('bodyTokens') is not None,
                unambiguousDeclarationContext=f['unambiguousDeclarationContext'])


def caller_state(old, old_keys, new_keys, new_functions):
    d = old['declaration']; key = d['correspondenceID']
    a, b = old_keys[key], new_keys[key]
    if len(a) != 1 or len(b) > 1 or not old['unambiguousDeclarationContext']:
        return 'ambiguous-correspondence'
    if len(b) == 1:
        if not b[0]['unambiguousDeclarationContext']:
            return 'ambiguous-correspondence'
        n = b[0]['declaration']
        if d['lexicalScopeHeaders'] != n['lexicalScopeHeaders']:
            return 'paired-header-changed'
        return 'paired-token-identical' if d['declarationTokens'] == n['declarationTokens'] else 'paired-declaration-changed'
    exact = [f for f in new_functions if f['declaration']['declarationTokens'] == d['declarationTokens']]
    if exact:
        return 'no-key-counterpart-token-identical-elsewhere'
    if any(f['declaration']['selector'] == d['selector'] for f in new_functions):
        return 'no-key-counterpart-same-selector-remains'
    return 'no-key-counterpart-no-same-selector'


def candidate_status(old_matches, new_matches, old_keys, new_keys):
    if len(old_matches) != 1 or len(new_matches) != 1:
        return 'same-selector-declaration-not-unique'
    a, b = old_matches[0], new_matches[0]; d, n = a['declaration'], b['declaration']
    if d.get('bodyTokens') is None or n.get('bodyTokens') is None:
        return 'declaration-without-body'
    if d['correspondenceID'] != n['correspondenceID']:
        return 'target-correspondence-changed'
    if len(old_keys[d['correspondenceID']]) != 1 or len(new_keys[n['correspondenceID']]) != 1 or not (a['unambiguousDeclarationContext'] and b['unambiguousDeclarationContext']):
        return 'target-correspondence-ambiguous'
    if d['lexicalScopeHeaders'] != n['lexicalScopeHeaders']:
        return 'target-header-changed'
    if d['declarationTokens'] != n['declarationTokens']:
        return 'target-declaration-changed'
    return 'retained-token-identical-candidate'


def analyze(case, index, prefix, needs):
    old, new = index['before']['functions'], index['after']['functions']
    old_keys, new_keys = grouped(old, 'correspondenceID'), grouped(new, 'correspondenceID')
    old_selectors, new_selectors = grouped(old, 'selector'), grouped(new, 'selector')
    calls = {}
    for side, fs in [('before', old), ('after', new)]:
        g = defaultdict(list)
        for f in fs:
            for c in f['declaration']['writtenCalls']:
                g[c['selector']].append((f, c))
        calls[side] = g
    groups = []
    for selector in sorted(calls['before']):
        a, b = calls['before'][selector], calls['after'][selector]
        if len(a) <= len(b):
            continue
        om, nm = old_selectors[selector], new_selectors[selector]
        status = candidate_status(om, nm, old_keys, new_keys)
        record = dict(selector=selector, beforeCount=len(a), afterCount=len(b),
                      beforeForms=dict(sorted(Counter(c['form'] for _, c in a).items())),
                      afterForms=dict(sorted(Counter(c['form'] for _, c in b).items())),
                      status=status, beforeDeclarations=[function_fact(f) for f in om],
                      afterDeclarations=[function_fact(f) for f in nm])
        for side, occurrences in [('before', a), ('after', b)]:
            facts = [dict(site=position(c['site']), form=c['form'], caller=position(f['declaration']['site']),
                callerSelector=f['declaration']['selector'],
                callerState=caller_state(f, old_keys, new_keys, new) if side == 'before' else 'after-indexed-caller',
                receiverSpellingSHA256=digest(c.get('receiverSpelling')),
                conditionsSHA256=digest(c['writtenConditions']),
                conditionPositions=[condition_fact(condition) for condition in c['writtenConditions']])
                for f,c in occurrences]
            record[side+'OccurrencesSHA256'] = digest(facts)
            # Keep every group/count/status. Rejected groups have no candidate
            # to navigate to; their full sites remain in the bound private index.
            if status == 'retained-token-identical-candidate':
                record[side+'Occurrences'] = facts
        record['needIntersections'] = [need['id'] for need in needs
            if status == 'retained-token-identical-candidate' and any(
                intersects(f['declaration']['site'], need['file'][len(prefix):], need['after']) for f in nm)]
        groups.append(record)
    need_results = []
    for need in needs:
        file = need['file']; in_scope = file.startswith(prefix)
        local_file = file[len(prefix):] if in_scope else file
        candidates = [g['selector'] for g in groups if need['id'] in g['needIntersections']]
        matched = {}
        for side in ['before', 'after']:
            snapshot = index[side]
            matched[side] = dict(functions=[function_fact(f) for f in snapshot['functions'] if intersects(f['declaration']['site'],local_file,need[side])],
                properties=[dict(site=position(p['site']),name=p['name']) for p in snapshot['properties'] if intersects(p['site'],local_file,need[side])],
                declarations=[dict(site=position(d['site']),name=d['name'],kind=d['kind']) for d in snapshot['declarations'] if intersects(d['site'],local_file,need[side])])
        if not in_scope:
            reason='outside-production-prefix'
        elif candidates:
            reason='retained-candidate-position-intersection'
        elif not matched['after']['functions']:
            reason='required-position-not-indexed-function'
        else:
            selectors={f['selector'] for f in matched['after']['functions']}
            reduced=[g for g in groups if g['selector'] in selectors]
            reason='no-decreased-written-selector' if not reduced else 'decreased-selector-target-ineligible'
        need_results.append(dict(id=need['id'],use=need['use'],file=file,before=need['before'],after=need['after'],
            reason=reason,candidateSelectors=candidates,indexMatches=matched))
    format_counts={}
    for side in ['before','after']:
        all_calls=index[side]['calls']
        format_counts[side]=dict(allASTCalls=len(all_calls),
            indexedBodyCalls=sum(len(fs) for fs in calls[side].values()),
            allASTForms=dict(sorted(Counter(c['form'] for c in all_calls).items())),
            allASTTrailing=sum(c['trailingClosure'] for c in all_calls),
            allASTBodyOwned=sum(c['callerBodyOwned'] for c in all_calls))
    return dict(case=case,formatCounts=format_counts,decreasedGroups=groups,needs=need_results,
        summary=dict(decreasedSelectors=len(groups),retainedCandidates=sum(g['status']=='retained-token-identical-candidate' for g in groups),
            statuses=dict(sorted(Counter(g['status'] for g in groups).items())),
            needReasons=dict(sorted(Counter(n['reason'] for n in need_results).items()))))


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--index',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--binary',type=Path,required=True,help='Own diagnostic binary used by the completed replay; hash checked, never executed here')
    p.add_argument('--manifest',type=Path,default=Path(__file__).parents[1]/'ResultHoldout/inputs.json')
    p.add_argument('--needs',type=Path,default=Path(__file__).with_name('needs.json'))
    args=p.parse_args()
    manifest=json.loads(args.manifest.read_text()); needs=json.loads(args.needs.read_text())['needs']
    expected={c['id']+'.json' for c in manifest}
    actual={p.name for p in args.index.glob('*.json') if p.name != 'execution.json'}
    if actual != expected:
        raise ValueError('Index case inventory differs from fixed manifest')
    receipt=json.loads((args.index/'execution.json').read_text())
    if receipt['inputsSHA256'] != hashlib.sha256(args.manifest.read_bytes()).hexdigest():
        raise ValueError('Execution input manifest differs')
    if receipt['binarySHA256'] != hashlib.sha256(args.binary.read_bytes()).hexdigest():
        raise ValueError('Execution binary differs')
    if receipt['runnerSHA256'] != hashlib.sha256(Path(__file__).with_name('run.py').read_bytes()).hexdigest():
        raise ValueError('Execution runner differs; use the matching diagnostic source for replay')
    if receipt['validatedEntries'] != sum(len(c['files']) for c in manifest):
        raise ValueError('Execution input inventory count differs')
    records=receipt['results']
    if len(records)!=len(manifest) or {r['case'] for r in records}!={c['id'] for c in manifest}:
        raise ValueError('Incomplete or duplicate execution case records')
    for r in records:
        if r['exit']!=0 or r['allExitStdoutStderrBytesEqual'] is not True:
            raise ValueError('Execution failed or was unstable')
        for suffix,key in [('json','stdoutSHA256'),('stderr','stderrSHA256')]:
            if hashlib.sha256((args.index/(r['case']+'.'+suffix)).read_bytes()).hexdigest()!=r[key]:
                raise ValueError('Execution output bytes differ: '+r['case'])
    results=[]
    for c in manifest:
        j=json.loads((args.index/(c['id']+'.json')).read_text())
        results.append(analyze(c['id'],j,c['prefix'],[n for n in needs if n['case']==c['id']]))
    args.output.parent.mkdir(parents=True,exist_ok=True)
    args.output.write_text(json.dumps(dict(meaning='Known-input syntax diagnostic, not resolved callees, migrations, coverage, review benefit or design verdict.',
        inputsSHA256=hashlib.sha256(args.manifest.read_bytes()).hexdigest(),needsSHA256=hashlib.sha256(args.needs.read_bytes()).hexdigest(),
        executionSHA256=hashlib.sha256((args.index/'execution.json').read_bytes()).hexdigest(),
        auditSHA256=hashlib.sha256(Path(__file__).read_bytes()).hexdigest(),cases=results),sort_keys=True,ensure_ascii=False,indent=2)+'\n')


if __name__=='__main__':
    main()
