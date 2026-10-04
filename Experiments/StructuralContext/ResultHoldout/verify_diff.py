"""Bind a saved GitHub unified diff to verified before/after bytes, without execution."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shlex


def check(condition, message):
    if not condition:
        raise ValueError(message)


def verify_diff(old, new, changes, data):
    expected = {}
    paths = set()
    for change in changes:
        status = change['status']; after = change['filename']
        before = change.get('previous_filename', after)
        check(status in ['added', 'removed', 'modified', 'renamed'], 'Unsupported changed-path status')
        check((before, after) not in expected, 'Duplicate diff path pair')
        expected[before, after] = status; paths.update([before, after])
        check((before in old) == (status != 'added'), 'Before path/status mismatch')
        check((after in new) == (status != 'removed'), 'After path/status mismatch')
    actual = {p for p in set(old) | set(new) if old.get(p) != new.get(p)}
    check(actual == paths, 'Changed snapshot paths differ from change metadata')
    lines = data.splitlines(keepends=True)
    starts = [i for i, line in enumerate(lines) if line.startswith(b'diff --git ')]
    check(bool(starts) or not expected, 'Missing unified diff')
    check(not starts or starts[0] == 0, 'Unexpected diff preamble')
    records = []; seen = set()
    for start, end in zip(starts, starts[1:] + [len(lines)]):
        block = lines[start:end]
        # GitHub's fixed cases have unescaped UTF-8 paths. Reject C-escaped paths rather than misdecode.
        check(b'\\' not in block[0], 'Unsupported C-escaped diff path')
        header = shlex.split(block[0].decode('utf-8'))
        check(len(header) == 4 and header[2].startswith('a/') and header[3].startswith('b/'), 'Invalid diff header')
        before, after = header[2][2:], header[3][2:]
        pair = before, after
        check(pair in expected and pair not in seen, 'Unexpected/duplicate diff path pair')
        seen.add(pair); status = expected[pair]
        added = any(l.startswith(b'new file mode ') for l in block)
        removed = any(l.startswith(b'deleted file mode ') for l in block)
        renamed = any(l.startswith(b'rename from ') for l in block)
        observed = 'added' if added else 'removed' if removed else 'renamed' if renamed else 'modified'
        check(observed == status and sum([added, removed, renamed]) <= 1, 'Diff status marker mismatch')
        if status == 'added': check(any(l.startswith(b'new file mode ') for l in block), 'Missing added status')
        if status == 'removed': check(any(l.startswith(b'deleted file mode ') for l in block), 'Missing removed status')
        if status == 'renamed':
            check(b'rename from ' + before.encode() + b'\n' in block, 'Rename source mismatch')
            check(b'rename to ' + after.encode() + b'\n' in block, 'Rename destination mismatch')
        a, amode = old.get(before, (b'', None)); b, bmode = new.get(after, (b'', None))
        old_modes = [l for l in block if l.startswith(b'old mode ')]
        new_modes = [l for l in block if l.startswith(b'new mode ')]
        if amode is not None and bmode is not None and amode != bmode:
            check(old_modes == [b'old mode ' + amode.encode() + b'\n'] and new_modes == [b'new mode ' + bmode.encode() + b'\n'], 'Missing mode change markers')
        else:
            check(not old_modes and not new_modes, 'Unexpected mode change markers')
        for line in block:
            if line.startswith(b'new file mode '): check(line.split()[-1].decode() == bmode, 'Added mode mismatch')
            if line.startswith(b'deleted file mode '): check(line.split()[-1].decode() == amode, 'Removed mode mismatch')
            if line.startswith(b'old mode '): check(line.split()[-1].decode() == amode, 'Old mode mismatch')
            if line.startswith(b'new mode '): check(line.split()[-1].decode() == bmode, 'New mode mismatch')
        binary = any(l.startswith(b'Binary files ') for l in block)
        if binary:
            check(a != b, 'Binary marker without changed bytes')
            check(not any(l.startswith(b'@@') for l in block), 'Mixed binary/text diff')
            records.append({'before': before, 'after': after, 'status': status, 'verification': 'binary metadata only; no text hunk', 'hunks': 0})
            continue
        aa, bb = a.splitlines(keepends=True), b.splitlines(keepends=True)
        if any(l.startswith(b'@@') for l in block):
            old_marker = b'/dev/null' if status == 'added' else b'a/' + before.encode()
            new_marker = b'/dev/null' if status == 'removed' else b'b/' + after.encode()
            check(b'--- ' + old_marker + b'\n' in block and b'+++ ' + new_marker + b'\n' in block, 'Hunk file marker mismatch')
        ac = bc = count = 0; i = 1
        while i < len(block):
            line = block[i]
            if not line.startswith(b'@@'):
                i += 1; continue
            m = re.match(rb'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', line)
            check(m is not None, 'Malformed hunk header')
            ast, an, bst, bn = [int(x) for x in [m[1], m[2] or b'1', m[3], m[4] or b'1']]
            ai = ast - 1 if an else ast; bi = bst - 1 if bn else bst
            check(ac <= ai <= len(aa) and bc <= bi <= len(bb), 'Overlapping/out-of-range hunk')
            check(aa[ac:ai] == bb[bc:bi], 'Unreported changed prefix/gap')
            left = []; right = []; previous = None; i += 1
            while i < len(block) and not block[i].startswith(b'@@'):
                l = block[i]; prefix = l[:1]
                if l.startswith(b'\\ No newline at end of file'):
                    check(previous in [b' ', b'-', b'+'], 'Invalid no-newline marker')
                    for output in ([left, right] if previous == b' ' else [left] if previous == b'-' else [right]):
                        check(output[-1].endswith(b'\n'), 'Invalid duplicate no-newline marker')
                        output[-1] = output[-1][:-1]
                else:
                    check(prefix in [b' ', b'-', b'+'], 'Unexpected hunk line')
                    if prefix in [b' ', b'-']: left.append(l[1:])
                    if prefix in [b' ', b'+']: right.append(l[1:])
                    previous = prefix
                i += 1
            check(len(left) == an and len(right) == bn, 'Hunk line counts differ')
            check(aa[ai:ai + an] == left and bb[bi:bi + bn] == right, 'Hunk does not match fixed source')
            ac = ai + an; bc = bi + bn; count += 1
        check(aa[ac:] == bb[bc:], 'Unreported changed tail or missing hunks')
        records.append({'before': before, 'after': after, 'status': status, 'verification': 'text hunks and unchanged gaps/tail', 'hunks': count})
    check(seen == set(expected), 'Missing diff path pair')
    return records


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--manifest', type=Path, required=True)
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    args = p.parse_args(); cases = []
    for case in json.loads(args.manifest.read_text()):
        sources = {'before': {}, 'after': {}}
        for side in sources:
            root = args.input / case['id'] / side
            entries = {f['path']: f for f in case['files'] if f['side'] == side}
            check({str(p.relative_to(root)) for p in root.rglob('*') if p.is_file()} == set(entries), 'Input inventory differs')
            for path, entry in entries.items():
                file = root / path; check(not file.is_symlink(), 'Symlink source')
                data = file.read_bytes()
                check(len(data) == entry['bytes'] and hashlib.sha256(data).hexdigest() == entry['sha256'], 'Source size/SHA mismatch')
                check(hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest() == entry['blob'], 'Source Git blob mismatch')
                sources[side][path] = data, entry['mode']
        data = (args.input / case['id'] / 'ordinary.diff').read_bytes()
        check(hashlib.sha256(data).hexdigest() == case['diffSHA256'], 'Diff SHA mismatch')
        cases.append({'case': case['id'], 'diffSHA256': case['diffSHA256'], 'files': verify_diff(sources['before'], sources['after'], case['changes'], data)})
    args.output.write_text(json.dumps({'meaning': 'Read-only diff/source binding; not behavior or design validation', 'cases': cases}, indent=2) + '\n')
    print('PASS: fixed snapshot paths/status/modes and textual hunks/gaps/tails')


if __name__ == '__main__':
    main()
