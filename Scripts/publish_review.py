"""Publish escaped report data using only code from the default branch."""
import io
import json
import os
from pathlib import Path
import re
import subprocess
import zipfile

from ci_review import render_summary

MARKER = '<!-- sekka-pr-review -->'
LIMIT = 4 * 1024 * 1024


def api(path, payload=None):
    args = ['gh', 'api', path]
    if payload is not None:
        args += ['--method', 'PATCH' if '/issues/comments/' in path else 'POST', '--input', '-']
    return json.loads(subprocess.check_output(args, input=None if payload is None else json.dumps(payload).encode()))


def read_bundle(data, expected_head):
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        if sum(f.file_size for f in archive.infolist()) > LIMIT:
            raise ValueError('Review artifact is too large')
        names = ['manifest.json', 'candidate.compact', 'candidate.text']
        if any(archive.namelist().count(name) != 1 for name in names):
            raise ValueError('Missing or duplicate review file')
        manifest = json.loads(archive.read(names[0]))
        report = json.loads(archive.read(names[1]))
        text = archive.read(names[2]).decode('utf-8')
    if manifest['head'] != expected_head or not re.fullmatch('[0-9a-f]{40}', manifest['base']):
        raise ValueError('Review input does not match run')
    if len(manifest['changedFiles']) > 10000 or any(not isinstance(f, str) for f in manifest['changedFiles']):
        raise ValueError('Invalid changed file list')
    return manifest, report, text


def current_pr(pr, run, repository):
    return (pr['state'] == 'open' and pr['base']['repo']['full_name'] == repository
            and pr['head']['sha'] == run['head_sha']
            and pr['head']['repo']['full_name'] == run['head_repository']['full_name'])


def owned_comment(comments):
    return next((c for c in comments if c['user']['login'] == 'github-actions[bot]'
                 and c['user']['type'] == 'Bot' and c['body'].startswith(MARKER)), None)


def main():
    repository = os.environ['GITHUB_REPOSITORY']
    run_id = int(os.environ['SEKKA_RUN_ID'])
    prefix = f'repos/{repository}'
    run = api(f'{prefix}/actions/runs/{run_id}')
    if run['event'] != 'pull_request' or run['path'] != '.github/workflows/pr-review.yml' or run['status'] != 'completed':
        raise ValueError('Not a completed Sekka PR review run')
    candidates = run['pull_requests'] or api(f"{prefix}/commits/{run['head_sha']}/pulls")
    matches = []
    for item in candidates:
        pr = api(f"{prefix}/pulls/{int(item['number'])}")
        if current_pr(pr, run, repository):
            matches.append(pr)
    if len(matches) != 1:
        print('No unique open PR with matching current head; skipped')
        return
    pr = matches[0]
    number = pr['number']
    run_url = f'https://github.com/{repository}/actions/runs/{run_id}'
    if run['conclusion'] == 'success':
        artifacts = api(f'{prefix}/actions/runs/{run_id}/artifacts')['artifacts']
        matches = [a for a in artifacts if a['name'] == f'sekka-review-{number}' and not a['expired']]
        if len(matches) != 1 or matches[0]['size_in_bytes'] > LIMIT:
            raise ValueError('No unique bounded review artifact')
        data = subprocess.check_output(['gh', 'api', f"{prefix}/actions/artifacts/{matches[0]['id']}/zip"])
        manifest, report, text = read_bundle(data, run['head_sha'])
        comparison = api(f"{prefix}/compare/{pr['base']['sha']}...{run['head_sha']}")
        if manifest['base'] != comparison['merge_base_commit']['sha']:
            print('PR base changed since analysis; skipped')
            return
        body = MARKER + '\n' + render_summary(manifest, report, text, f'https://github.com/{repository}', str(number), run_url)
    else:
        body = (MARKER + '\n## 🐦 Sekka — 結果を更新できませんでした\n\n'
                f"対象: `{run['head_sha']}`\n\n"
                '⚠️ チェックまたは解析が完了しなかったため、このコミットの構造案内はありません。設計の不合格を示すものではありません。\n\n'
                f'[実行ログを確認]({run_url})\n')
    if len(body) > 60000:
        raise ValueError('Rendered comment exceeds limit')
    comments = []
    for page in range(1, 101):
        batch = api(f'{prefix}/issues/{number}/comments?per_page=100&page={page}')
        comments.extend(batch)
        if len(batch) < 100:
            break
    else:
        raise ValueError('Too many comments to safely find prior report')
    existing = owned_comment(comments)
    # Recheck after download/rendering: a synchronize event may have overtaken this run.
    if not current_pr(api(f'{prefix}/pulls/{number}'), run, repository):
        print('PR head changed before publish; skipped')
        return
    if os.environ.get('SEKKA_DRY_RUN') == '1':
        Path(os.environ['SEKKA_PREVIEW_PATH']).write_text(body)
        print('Preview saved; no comment posted')
        return
    if existing:
        result = api(f"{prefix}/issues/comments/{existing['id']}", {'body': body})
    else:
        result = api(f'{prefix}/issues/{number}/comments', {'body': body})
    print(result['html_url'])


if __name__ == '__main__':
    main()
