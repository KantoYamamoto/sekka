"""Publish a bounded, escaped Actions summary from the local review bundle."""
import hashlib
import html
import json
import os
from pathlib import Path
import subprocess

from self_review import capture


def render_summary(manifest, report, text, repo_url, pr_number, run_url):
    coverage = report["coverage"]
    swift_files = coverage["changedFiles"]
    unobserved = sum(f["observationCount"] == 0 for f in swift_files)
    lines = [
        "# Sekka · PR review guide", "",
        "構文上の変更から読む場所を選ぶ案内です。通常diffも確認してください。", "",
        "| 変更Swiftファイル | 構造観測 | 観測のない変更ファイル | 本体比較省略 |",
        "| ---: | ---: | ---: | ---: |",
        f"| {len(swift_files)} | {len(report['findings'])} | {unobserved} | {coverage['skippedBodyCount']} |",
        "",
    ]
    if not swift_files:
        lines += ["今回、解析対象のSwift差分はありません。設定・文書・スクリプトの変更は通常のPR diffで確認してください。", ""]
    lines += ["## 確認するファイル", ""]
    files = manifest["changedFiles"]
    for file in files[:20]:
        anchor = hashlib.sha256(file.encode()).hexdigest()
        url = f"{repo_url}/pull/{pr_number}/files#diff-{anchor}" if pr_number else f"{repo_url}/commit/{manifest['head']}"
        lines.append(f'- <a href="{html.escape(url, quote=True)}"><code>{html.escape(file)}</code></a>')
    if len(files) > 20:
        lines.append(f"残り{len(files) - 20}ファイルはmanifest.jsonとPRのFiles changedを参照してください。")
    lines += ["", "<details><summary>Sekkaの構造案内を開く</summary>", "", "<pre>" + html.escape(text[:16000]) + "</pre>"]
    if len(text) > 16000:
        lines.append("表示を16,000文字で区切っています。完全版は成果物candidate.textを参照してください。")
    lines += [
        "", "</details>", "",
        f"比較: `{manifest['base']}` → `{manifest['head']}`", "",
        "評価器はこのPRでビルドしたSekkaです。独立したレビューや設計の合否判定ではありません。", "",
        f"[実行と成果物]({run_url})：通常diff・完全なtext・JSON・入力IDと評価器hash。保存期間は14日です。",
    ]
    return "\n".join(lines) + "\n"


def main():
    repo = Path.cwd()
    head = os.environ["SEKKA_HEAD"]
    base = subprocess.check_output(
        ["git", "merge-base", os.environ["SEKKA_BASE"], head], text=True
    ).strip()
    output = repo / ".build/pr-review"
    manifest = capture(repo, base, head, repo / ".build/debug/sekka", output)
    report = json.loads((output / "candidate.compact").read_text())
    repo_url = os.environ.get("GITHUB_SERVER_URL", "https://github.com") + "/" + os.environ["GITHUB_REPOSITORY"]
    summary = render_summary(
        manifest, report, (output / "candidate.text").read_text(), repo_url,
        os.environ.get("SEKKA_PR", ""), repo_url + "/actions/runs/" + os.environ["GITHUB_RUN_ID"],
    )
    (output / "summary.md").write_text(summary)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as stream:
        stream.write(summary)
    print("Review material generated for", manifest["base"], "→", manifest["head"])


if __name__ == "__main__":
    main()
