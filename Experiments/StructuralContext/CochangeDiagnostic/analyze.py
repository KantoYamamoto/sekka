"""Diagnostic relationships between written switch-shape changes; no semantic verdict."""
import hashlib
import json
from collections import defaultdict


def key(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'))


def sha(value):
    return hashlib.sha256(key(value).encode()).hexdigest()


def group(items, get_key):
    result = defaultdict(list)
    for item in items:
        result[get_key(item)].append(item)
    return result


def shape(switch):
    # Arguments and enclosing conditions deliberately remain separate evidence.
    # Do not call this equivalence, execution order or a resolved API sequence.
    return [[b['label'], [[c['form'], c['calledExpression'], c.get('selector'), c['trailingClosures']]
                        for c in b['calls']]] for b in switch['branches']]


def switch_key(switch):
    if not switch.get('owner'):
        return None
    return key([switch['owner']['key'], switch['expression'], switch['conditions']])


def analyze(report):
    before, after = report['before'], report['after']
    regions = {side: group(report[side]['regions'], lambda r: key(r['key'])) for side in ('before', 'after')}
    switches = {side: group(report[side]['switches'], switch_key) for side in ('before', 'after')}
    transitions, unknown = [], []
    for identity in sorted(set(switches['before']) | set(switches['after']), key=lambda x: x or ''):
        old, new = switches['before'].get(identity, []), switches['after'].get(identity, [])
        reason = None
        if identity is None:
            reason = 'no-executable-owner'
        elif len(old) != 1 or len(new) != 1:
            reason = 'added-deleted-or-ambiguous-switch'
        elif any(len(regions[side].get(key(s['owner']['key']), [])) != 1
                 for side, s in (('before', old[0]), ('after', new[0]))):
            reason = 'ambiguous-owner'
        elif old[0]['containsConditionalCases'] or new[0]['containsConditionalCases']:
            reason = 'conditional-case-list-not-expanded'
        if reason:
            unknown.append({'reason': reason, 'before': [s['site'] for s in old], 'after': [s['site'] for s in new]})
            continue
        old, new = old[0], new[0]
        if old['tokens'] == new['tokens']:
            continue
        transitions.append({'before': old, 'after': new, 'shapeChanged': shape(old) != shape(new)})
    groups = group([t for t in transitions if t['shapeChanged'] and len(t['after']['branches']) >= 2],
                   lambda t: key([shape(t['before']), shape(t['after'])]))
    relationships = []
    for identity, members in sorted(groups.items()):
        if len(members) < 2:
            continue
        # Equal shapes do not assert equal arguments, conditions, types or purposes.
        argument_vectors = [[[[c['argumentTokens'] for c in b['calls']] for b in t[side]['branches']]
                             for side in ('before', 'after')] for t in members]
        relationships.append({'id': sha(identity), 'meaning': 'same-written-switch-shape-transition',
            'argumentSpellingsDiffer': len({key(a) for a in argument_vectors}) > 1,
            'enclosingConditionsDiffer': len({key(t['after']['conditions']) for t in members}) > 1,
            'members': members})
    # Candidate users by explicit written selector, including property/initializer bodies.
    # Neither unique written declaration nor a matched spelling resolves the callee.
    users = []
    selectors = sorted({t['after']['owner']['selector'] for r in relationships for t in r['members']
                        if t['after']['owner'].get('selector')})
    for selector in selectors:
        for side in ('before', 'after'):
            for call in report[side]['calls']:
                if call.get('selector') != selector or not call.get('owner'):
                    continue
                k = key(call['owner']['key'])
                old, new = regions['before'].get(k, []), regions['after'].get(k, [])
                state = 'unpaired-or-ambiguous'
                if len(old) == len(new) == 1:
                    state = 'token-identical' if old[0]['tokens'] == new[0]['tokens'] else 'changed'
                users.append({'selector': selector, 'side': side, 'call': call, 'ownerState': state,
                              'callee': 'unresolved-written-selector-only'})
    return {'meaning': 'Diagnostic facts, not shared behavior, dependency, required abstraction or design judgment',
            'relationships': relationships, 'users': users, 'unknown': unknown,
            'transitionCount': len(transitions), 'switchCounts': {s: len(report[s]['switches']) for s in ('before', 'after')},
            'unresolved': ['argument-values', 'receiver-types', 'callee', 'active-conditions', 'execution-order', 'purpose', 'performance']}


if __name__ == '__main__':
    import argparse
    from pathlib import Path
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('input', type=Path)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args()
    args.output.write_text(json.dumps(analyze(json.loads(args.input.read_text())), ensure_ascii=False, indent=2) + '\n')
