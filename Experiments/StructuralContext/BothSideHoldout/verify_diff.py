"""Bind unquoted GitHub paths with spaces to frozen metadata, then verify all hunks."""
import importlib.util
from pathlib import Path
import shlex

legacy = Path(__file__).parents[1] / 'ResultHoldout/verify_diff.py'
spec = importlib.util.spec_from_file_location('frozen_material_verifier', legacy)
base = importlib.util.module_from_spec(spec); spec.loader.exec_module(base)
verify_normalized = base.verify_diff


def verify_diff(old, new, changes, data):
    headers = {}
    for change in changes:
        after = change['filename']; before = change.get('previous_filename', after)
        for path in (before, after):
            base.check(not any(c in path for c in '\n\r\t\\'), 'Unsupported escaped/control path')
        header = ('diff --git a/' + before + ' b/' + after + '\n').encode()
        base.check(header not in headers, 'Ambiguous metadata-bound diff header')
        headers[header] = (before, after, change['status'])
    result = []; markers = None
    for line in data.splitlines(keepends=True):
        if line.startswith(b'diff --git '):
            base.check(line in headers, 'Header does not match exactly one frozen path pair')
            before, after, status = headers[line]
            result.append(('diff --git ' + shlex.quote('a/' + before) + ' ' + shlex.quote('b/' + after) + '\n').encode())
            markers = {
                (b'--- /dev/null' if status == 'added' else ('--- a/' + before).encode()),
                (b'+++ /dev/null' if status == 'removed' else ('+++ b/' + after).encode())}
        elif line.startswith((b'--- ', b'+++ ')) and markers is not None and line[:-2] in markers and line.endswith(b'\t\n'):
            # GitHub terminates unquoted space-containing file markers with a tab.
            result.append(line[:-2] + b'\n')
        elif line.startswith(b'@@'):
            markers = None
            result.append(line)
        else:
            result.append(line)
    # Only path syntax is normalized; hunk/status/mode/content checks remain unchanged.
    return verify_normalized(old, new, changes, b''.join(result))


if __name__ == '__main__':
    base.verify_diff = verify_diff
    base.main()
