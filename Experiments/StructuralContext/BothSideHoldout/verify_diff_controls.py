"""Space-path material controls; no third-party source or target execution."""
from verify_diff import verify_diff

name = 'Sources/A b.swift'
old = {name: (b'old\n', '100644')}; new = {name: (b'new\n', '100644')}
changes = [dict(filename=name, status='modified')]
diff = ('diff --git a/' + name + ' b/' + name + '\nindex 111..222 100644\n--- a/' + name + '\t\n+++ b/' + name + '\t\n@@ -1 +1 @@\n-old\n+new\n').encode()
verify_diff(old, new, changes, diff)
verify_diff(old, new, changes, diff.replace(b'\t\n', b'\n'))
renamed = 'Sources/New b.swift'
rename = diff.replace((' b/'+name+'\n').encode(), (' b/'+renamed+'\n').encode(), 1)
rename = rename.replace(b'index 111..222 100644\n', ('rename from '+name+'\nrename to '+renamed+'\n').encode())
rename = rename.replace(('+++ b/'+name).encode(), ('+++ b/'+renamed).encode())
verify_diff(old, {renamed: new[name]}, [dict(filename=renamed,previous_filename=name,status='renamed')], rename)
# A deleted source line can resemble a file marker; never normalize hunk content.
content = ('-- a/' + name + '\t\n').encode()
body = diff.split(b'@@')[0] + b'@@ -1 +1 @@\n-' + content + b'+new\n'
verify_diff({name: (content,'100644')},new,changes,body)
bad = [diff.replace(b'A b.swift b/', b'A c.swift b/',1),
       diff.replace(b'+++ b/Sources/A b.swift\t', b'+++ b/Sources/A c.swift\t'),
       diff.replace(b'+new\n', b'+wrong\n'), diff.split(b'@@')[0], diff+diff,
       diff.replace(b'\t\n', b'\tignored\n')]
for data in bad:
    try: verify_diff(old,new,changes,data)
    except ValueError: pass
    else: raise AssertionError('Invalid space-path material accepted')
print('PASS: 4 valid space-path/rename/hunk-content controls; 6 altered/truncated/duplicate/marker controls rejected')
