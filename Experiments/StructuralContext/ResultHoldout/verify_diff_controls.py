"""Own synthetic input controls for the read-only material checker."""
from verify_diff import verify_diff


def fixture(status, before, after, old=b'old\n', new=b'new\n', body=None):
    changes = [{'filename': after, 'status': status}]
    if before != after: changes[0]['previous_filename'] = before
    left = {} if status == 'added' else {before: (old, '100644')}
    right = {} if status == 'removed' else {after: (new, '100644')}
    metadata = b''
    if status == 'added': metadata = b'new file mode 100644\n'
    if status == 'removed': metadata = b'deleted file mode 100644\n'
    if status == 'renamed': metadata = ('rename from ' + before + '\nrename to ' + after + '\n').encode()
    if body is None:
        body = b'@@ -1 +1 @@\n-old\n+new\n'
    metadata += b'--- ' + (b'/dev/null' if status == 'added' else ('a/' + before).encode()) + b'\n'
    metadata += b'+++ ' + (b'/dev/null' if status == 'removed' else ('b/' + after).encode()) + b'\n'
    diff = ('diff --git a/' + before + ' b/' + after + '\n').encode() + metadata + body
    return left, right, changes, diff


positive = [fixture('modified', 'File.swift', 'File.swift'),
            fixture('added', 'New.swift', 'New.swift', body=b'@@ -0,0 +1 @@\n+new\n'),
            fixture('removed', 'Old.swift', 'Old.swift', body=b'@@ -1 +0,0 @@\n-old\n'),
            fixture('renamed', 'Old.swift', 'New.swift'),
            fixture('modified', 'File.swift', 'File.swift', old=b'old', new=b'new', body=b'@@ -1 +1 @@\n-old\n\\ No newline at end of file\n+new\n\\ No newline at end of file\n'),
            fixture('modified', 'File.swift', 'File.swift', old=b'prefix\nold\ntail\n', new=b'prefix\nnew\ntail\n', body=b'@@ -2 +2 @@\n-old\n+new\n')]
for arguments in positive: verify_diff(*arguments)
mode = fixture('modified', 'File.swift', 'File.swift', new=b'old\n', body=b'')
mode = (mode[0], {'File.swift': (b'old\n', '100755')}, mode[2], mode[3])
verify_diff(*mode[:3], mode[3] + b'old mode 100644\nnew mode 100755\n')

valid = fixture('modified', 'File.swift', 'File.swift')
negative = [valid[:3] + (b'',), valid[:3] + (valid[3].replace(b'+new', b'+wrong'),),
            valid[:3] + (valid[3].replace(b'File.swift', b'Other.swift'),),
            valid[:3] + (valid[3].replace(b'@@ -1 +1 @@', b'@@ -1,2 +1 @@'),),
            valid[:3] + (valid[3] + valid[3],),
            (valid[0], {'File.swift': (b'new\nunreported\n', '100644')}, valid[2], valid[3]),
            (dict(valid[0], Missing=(b'a', '100644')), valid[1], valid[2], valid[3]),
            valid[:3] + (valid[3].split(b'@@')[0],),
            valid[:3] + (valid[3].replace(b'+++ b/File.swift', b'+++ b/Other.swift'),),
            valid[:3] + (valid[3].replace(b'--- a/File.swift', b'new file mode 100644\n--- a/File.swift'),), mode]
for arguments in negative:
    try: verify_diff(*arguments)
    except ValueError: pass
    else: raise AssertionError('Invalid material accepted')
print('PASS: seven valid text/status/mode/EOF controls; eleven missing/altered/truncated/duplicate/status/mode controls rejected')
