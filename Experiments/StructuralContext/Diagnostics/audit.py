"""Diagnose known needed positions. Emits metadata only, never source tokens."""
import argparse
from collections import defaultdict
import json
from pathlib import Path

p = argparse.ArgumentParser(description=__doc__)
p.add_argument('--index', type=Path, required=True)
p.add_argument('--contexts', type=Path, required=True)
p.add_argument('--needs', type=Path, default=Path(__file__).with_name('needs.json'))
p.add_argument('--output', type=Path, required=True)
args = p.parse_args()
needs = json.loads(args.needs.read_text())

def position(site):
    return {k: site[k] for k in ['file', 'line', 'endLine']}

def intersects(site, need):
    return site['file'] == need['file'] and site['line'] <= need['after'][1] and site['endLine'] >= need['after'][0]

def keyed(functions):
    result = defaultdict(list)
    for f in functions:
        result[f['declaration']['correspondenceID']].append(f)
    return result

cases = {}
for name in sorted(set(n['case'] for n in needs['needs']) | set(needs['negativeCases'])):
    index = json.loads((args.index / (name + '.json')).read_text())
    report = json.loads((args.contexts / (name + '.json')).read_text())
    old, new = index['before'], index['after']
    old_keys, new_keys = keyed(old['functions']), keyed(new['functions'])
    old_texts = defaultdict(set)
    for f in old['functions']:
        d = f['declaration']; old_texts[d['site']['file']].add(d['declarationTokens'])
    anchors = []
    for f in new['functions']:
        d = f['declaration']
        # For these fixed packets the changed-file gate is checked by before/after token inventory;
        # do not turn this diagnostic approximation into the production query's byte-file gate.
        if d['declarationTokens'] in old_texts[d['site']['file']]:
            continue
        previous = old_keys[d['correspondenceID']]
        paired = len(previous) == len(new_keys[d['correspondenceID']]) == 1 and f['unambiguousDeclarationContext'] and previous[0]['unambiguousDeclarationContext'] and previous[0]['declaration']['lexicalScopeHeaders'] == d['lexicalScopeHeaders']
        old_calls = {c['tokens'] for c in previous[0]['declaration']['writtenMemberCalls']} if paired else set()
        eligible = [c for c in d['writtenMemberCalls'] if not paired or c['tokens'] not in old_calls]
        anchors.append((f, paired, eligible))

    def unchanged(f):
        d = f['declaration']; prior = old_keys[d['correspondenceID']]
        if len(prior) != 1 or len(new_keys[d['correspondenceID']]) != 1 or not f['unambiguousDeclarationContext'] or not prior[0]['unambiguousDeclarationContext']:
            return 'unknown-correspondence'
        before = prior[0]['declaration']
        if before['lexicalScopeHeaders'] != d['lexicalScopeHeaders']:
            return 'changed-lexical-header'
        if before['declarationTokens'] != d['declarationTokens']:
            return 'changed-declaration/body-identical' if before.get('bodyTokens') == d.get('bodyTokens') and d.get('bodyTokens') is not None else 'changed-declaration'
        return 'token-identical/bodyless' if d.get('bodyTokens') is None else 'token-identical'

    calls_by_caller = defaultdict(list)
    for c in new['calls']:
        if c.get('caller') and c['callerBodyOwned']:
            calls_by_caller[(c['caller']['file'], c['caller']['line'])].append(c)
    old_calls_by_caller = defaultdict(list)
    for c in old['calls']:
        if c.get('caller') and c['callerBodyOwned']:
            old_calls_by_caller[(c['caller']['file'], c['caller']['line'])].append(c)

    def calls_in(f):
        site = f['declaration']['site']
        return calls_by_caller[(site['file'], site['line'])]

    local_names = defaultdict(list)
    for d in new['declarations']:
        local_names[d['name']].append(d)
    records = []
    for n in [n for n in needs['needs'] if n['case'] == name]:
        functions = [f for f in new['functions'] if intersects(f['declaration']['site'], n)]
        properties = [f for f in new['properties'] if intersects(f['site'], n)]
        declarations = [f for f in new['declarations'] if intersects(f['site'], n)]
        record = dict(n)
        record['selectedContextOverlaps'] = [position(t['after']) for t in report['contexts'] if intersects(t['after'], n)]
        record['indexedProperties'] = [{'name': f['name'], 'site': position(f['site'])} for f in properties]
        record['indexedTypes'] = [{'name': f['name'], 'kind': f['kind'], 'site': position(f['site'])} for f in declarations]
        record['indexedFunctions'] = []
        for target in functions:
            d = target['declaration']
            matches = sum(f['declaration']['selector'] == d['selector'] for f in new['functions'])
            exact_calls = [(f, c) for f, paired, eligible in anchors for c in eligible if c['selector'] == d['selector']]
            family = [f for f, _, _ in anchors if unchanged(target) == 'token-identical' and f['declaration']['correspondenceID'] != d['correspondenceID'] and f['declaration']['selector'].split('(')[0] == d['selector'].split('(')[0] and f['declaration']['lexicalScopeHeaders'] == d['lexicalScopeHeaders']]
            # Trial evidence: an unchanged consumer and an eligible anchor spell the same operation.
            # This is neither a resolved call relation nor a finding of duplicate responsibility.
            shared = []
            target_patterns = {(c['form'], c['selector'], c['trailingClosure']) for c in calls_in(target) if c.get('selector')}
            if unchanged(target) == 'token-identical':
                for anchor, paired, _ in anchors:
                    a = anchor['declaration']; previous = old_keys[a['correspondenceID']]
                    old_site = previous[0]['declaration']['site'] if paired else None
                    old_tokens = {c['tokens'] for c in old_calls_by_caller[(old_site['file'], old_site['line'])]} if old_site else set()
                    by_pattern = defaultdict(list)
                    for c in calls_in(anchor):
                        pattern = (c['form'], c.get('selector'), c['trailingClosure'])
                        if pattern in target_patterns and (not paired or c['tokens'] not in old_tokens):
                            by_pattern[pattern].append(c)
                    for pattern, occurrences in sorted(by_pattern.items()):
                        prior = [c for c in calls_in(target) if (c['form'], c.get('selector'), c['trailingClosure']) == pattern]
                        shared.append({'anchor': position(a['site']), 'form': pattern[0], 'selector': pattern[1], 'trailingClosure': pattern[2], 'anchorCall': position(occurrences[0]['site']), 'targetCall': position(prior[0]['site']), 'anchorOccurrences': len(occurrences), 'targetOccurrences': len(prior), 'anchorReturnNames': occurrences[0]['callerReturnNames'], 'targetReturnNames': prior[0]['callerReturnNames'], 'callerEvidence': 'paired/token-absent' if paired else 'no-unique-old-correspondence'})
            result_shared = [x for x in shared if x['form'] == 'unqualified' and not x['trailingClosure']
                and x['selector'].split('(')[0] in x['anchorReturnNames']
                and x['selector'].split('(')[0] in x['targetReturnNames']
                and len(local_names[x['selector'].split('(')[0]]) == 1]
            record['indexedFunctions'].append({'selector': d['selector'], 'site': position(d['site']), 'beforeAfter': unchanged(target), 'sameSelectorDeclarations': matches,
                'eligibleExactMemberOccurrences': len(exact_calls), 'exactMemberSites': [position(c['site']) for _, c in exact_calls],
                'sameWrittenHeaderNameFamilyAnchors': [position(f['declaration']['site']) for f in family], 'sharedWrittenOperationTrial': shared, 'sharedIndexedReturnNameTrial': result_shared})
        records.append(record)
    cases[name] = {'diagnosticAnchorFunctions': len(anchors), 'selectedContexts': len(report['contexts']), 'omittedTargets': report['omittedTargets'], 'omittedEntries': sum(t['omittedEntries'] for t in report['contexts']), 'needs': records}

args.output.parent.mkdir(parents=True, exist_ok=True)
args.output.write_text(json.dumps({'meaning': 'Known position diagnostic and trial spelling relations. Not a callee, duplication, coverage or usefulness verdict. No source tokens emitted.', 'cases': cases}, ensure_ascii=False, indent=2, sort_keys=True) + '\n')
