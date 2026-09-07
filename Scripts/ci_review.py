"""Publish a bounded, escaped Actions summary from the local review bundle."""
import hashlib
import html
import json
import os
from pathlib import Path
import subprocess

from self_review import capture


def tree_text(text):
    """Show existing indentation as a tree, preserving labels and facts."""
    lines = text.splitlines()
    rendered = []
    upcoming = set()
    for line in reversed(lines):
        spaces = len(line) - len(line.lstrip(' '))
        level = spaces // 2
        if not line.strip() or level == 0:
            upcoming.clear()
            rendered.append(line)
            continue
        upcoming = {depth for depth in upcoming if depth <= level}
        prefix = ''.join('│  ' if depth in upcoming else '   ' for depth in range(1, level))
        branch = '├─ ' if level in upcoming else '└─ '
        rendered.append(prefix + branch + line[spaces:])
        upcoming.add(level)
    return '\n'.join(reversed(rendered))


def render_summary(manifest, report, text, repo_url, pr_number, run_url):
    coverage = report["coverage"]
    swift_files = coverage["changedFiles"]
    unobserved = sum(f["observationCount"] == 0 for f in swift_files)
    lines = [
        "## Sekka — レビューの入口", "",
        "構文上の変更から読む場所を選ぶ案内です。通常diffも確認してください。", "",
        "| Swift変更 | 構造観測 | 構造観測なし | 本体比較省略 |",
        "| ---: | ---: | ---: | ---: |",
        f"| {len(swift_files)} | {len(report['findings'])} | {unobserved} | {coverage['skippedBodyCount']} |",
        "",
    ]
    if not swift_files:
        lines += ["今回、解析対象のSwift差分はありません。設定・文書・スクリプトの変更は通常のPR diffで確認してください。", ""]
    lines += ["### 確認するファイル", "", "Swiftの変更を先に表示します。観測の有無は確認済み範囲を意味しません。", ""]
    swift_paths = {f["file"]: f for f in swift_files}
    files = sorted(manifest["changedFiles"], key=lambda f: (f not in swift_paths, f))
    for file in files[:20]:
        anchor = hashlib.sha256(file.encode()).hexdigest()
        url = f"{repo_url}/pull/{pr_number}/files#diff-{anchor}" if pr_number else f"{repo_url}/commit/{manifest['head']}"
        label = "解析対象外" if file not in swift_paths else ("構造観測なし" if swift_paths[file]["observationCount"] == 0 else "Swift変更")
        lines.append(f'- [{label}] <a href="{html.escape(url, quote=True)}"><code>{html.escape(file)}</code></a>')
    if len(files) > 20:
        lines.append(f"残り{len(files) - 20}ファイルはmanifest.jsonとPRのFiles changedを参照してください。")
    # The runner-local replay command cannot be copied into a local checkout.
    display = "\n".join(line for line in text.splitlines() if not line.startswith("Inspect source hunks:"))
    escaped = html.escape(tree_text(display))
    # Bound the escaped payload too: source containing '<' can expand severalfold.
    preview = escaped[:16000]
    if len(escaped) > 16000 and "&" in preview and preview.rfind("&") > preview.rfind(";"):
        preview = preview[:preview.rfind("&")]
    lines += ["", "<details><summary>構造案内を開く</summary>", "", "<pre>" + preview + "</pre>"]
    if len(escaped) > 16000:
        lines.append("表示を16,000文字で区切っています。完全版は成果物candidate.textを参照してください。")
    lines += [
        "", "</details>", "",
        f"比較: `{manifest['base']}` → `{manifest['head']}`", "",
        "### この案内で分からないこと", "",
        "- 構造観測があるファイルにも、未観測の変更が混在します。通常diffも読んでください。",
        "- 本体比較は構文・トークンの比較です。動作や設計の正しさは判定しません。",
        "- 評価器はこのPRでビルドしたSekkaです。独立したレビューではありません。", "",
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
