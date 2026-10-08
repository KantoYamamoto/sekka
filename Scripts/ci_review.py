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


def escaped_preview(text, limit):
    escaped = html.escape(text)
    preview = escaped[:limit]
    if len(escaped) > limit and "&" in preview and preview.rfind("&") > preview.rfind(";"):
        preview = preview[:preview.rfind("&")]
    return preview, len(escaped) > limit


def render_summary(manifest, report, text, repo_url, pr_number, run_url, api_review=None, api_text=""):
    coverage = report["coverage"]
    swift_files = coverage["changedFiles"]
    inventory = report["inventory"]
    changes = inventory["changes"]
    unobserved = sum(f["observationCount"] == 0 for f in swift_files)
    lines = [
        "## Sekka — レビューの入口", "",
        "構文上の変更から読む場所を選ぶ案内です。通常diffも確認してください。", "",
        "| Swift変更（ファイル） | 構造観測（件） | 構造観測なし（ファイル） | 本体比較省略（本体） |",
        "| ---: | ---: | ---: | ---: |",
        f"| {len(swift_files)} | {len(report['findings'])} | {unobserved} | {coverage['skippedBodyCount']} |",
        "",
    ]
    if not swift_files:
        lines += ["今回、解析対象のSwift差分はありません。設定・文書・スクリプトの変更は通常のPR diffで確認してください。", ""]
    if api_review is not None:
        candidates = api_review["contract"]["changes"]
        adaptations = sum(len(c["adaptations"]) for c in candidates)
        lines += ["### API境界の比較（限定試行）", "",
                  f"このPRの実入力: 契約拡大の候補 {len(candidates)}件 / 追加値を捨てる既存closureの適応 {adaptations}箇所。",
                  "末尾引数が増えるcallbackの一形態だけが対象です。0件は設計の承認を意味しません。", ""]
        if candidates:
            preview, omitted = escaped_preview(api_text, 8000)
            lines += ["<details><summary>根拠とAPI境界の別案を開く</summary>", "", "<pre>" + preview + "</pre>"]
            if omitted:
                lines += ["表示を8,000文字で区切っています。完全版はapi-review.textを参照してください。"]
            lines += ["", "</details>", ""]
        lines += ["実PRの結果は成果物api-review.json/textに保存します。callback-contract.json/textは自作対照の結果で、このPRの検出件数には含めません。", ""]
    lines += ["### 確認するファイル", "", "Swiftの変更を先に表示します。観測の有無は確認済み範囲を意味しません。", ""]
    swift_paths = {f["file"]: f for f in swift_files}
    inventory_by_path = {item["file"]: item for item in changes}
    files = sorted(inventory_by_path, key=lambda f: (f not in swift_paths, f))
    lines += [f"比較対象の変更: {len(files)}パス。対象範囲: {html.escape(inventory['scope'])}", ""]
    bodies_by_path = {}
    for body in coverage.get("bodyComparisons", []):
        location = body.get("afterLocation") or body["beforeLocation"]
        bodies_by_path.setdefault(location["file"], []).append(body)

    def file_line(file):
        anchor = hashlib.sha256(file.encode()).hexdigest()
        url = f"{repo_url}/pull/{pr_number}/files#diff-{anchor}" if pr_number else f"{repo_url}/commit/{manifest['head']}"
        label = {
            "swift": "Swift解析対象", "non-swift": "非Swift・未解析",
            "excluded": "除外・未解析", "unsupported-file-kind": "非通常ファイル・未解析",
        }.get(inventory_by_path[file]["analysis"], "解析状態不明")
        if file in swift_paths:
            item = swift_paths[file]
            bodies = bodies_by_path.get(file, [])
            labels = [f"構造観測 {item['observationCount']}件"]
            syntax_only = sum(b["status"] == "changed-syntax-only" for b in bodies)
            skipped = sum(b["status"] == "not-compared" for b in bodies)
            if syntax_only:
                labels.append(f"本体token変更 {syntax_only}本体（構造指標は同じ）")
            if skipped:
                labels.append(f"本体未比較 {skipped}本体")
            if not item["syntaxChanged"]:
                labels.append("コメント・整形のみ")
            elif not item["observationCount"] and not bodies:
                labels.append("ファイルdiffで確認")
            label = " / ".join(labels)
        return f'- <a href="{html.escape(url, quote=True)}"><code>{html.escape(file)}</code></a> — [{html.escape(label)}]'

    analyzed = [file for file in files if file in swift_paths]
    remaining = [file for file in files if file not in swift_paths]
    lines += [file_line(file) for file in analyzed[:20]]
    if len(analyzed) > 20:
        lines.append(f"残り{len(analyzed) - 20}Swiftファイルはcandidate.compactのinventory.changesとPRのFiles changedを参照してください。")
    if remaining:
        lines += ["", f"<details><summary>その他の変更 {len(remaining)}パス（解析状態付き）</summary>", ""]
        lines += [file_line(file) for file in remaining[:5]]
        if len(remaining) > 5:
            lines.append(f"残り{len(remaining) - 5}パスはcandidate.compactのinventory.changesとPRのFiles changedを参照してください。")
        lines += ["", "</details>"]
    # The runner-local replay command cannot be copied into a local checkout.
    display = "\n".join(line for line in text.splitlines() if not line.startswith("Inspect source hunks:"))
    preview, omitted = escaped_preview(tree_text(display), 16000)
    lines += ["", "<details><summary>構造案内を開く</summary>", "", "<pre>" + preview + "</pre>"]
    if omitted:
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
    # The same frozen evaluator and source refs as the structural report; no target checkout/build.
    binary = output / "candidate-sekka"
    api_args = [str(binary), "review", base, "--head", head, "--path", str(repo)]
    for format, name in [("json", "api-review.json"), ("text", "api-review.text")]:
        result = subprocess.run(api_args + ["--format", format], capture_output=True, check=True)
        (output / name).write_bytes(result.stdout)
    api_review = json.loads((output / "api-review.json").read_text())
    report = json.loads((output / "candidate.compact").read_text())
    repo_url = os.environ.get("GITHUB_SERVER_URL", "https://github.com") + "/" + os.environ["GITHUB_REPOSITORY"]
    summary = render_summary(
        manifest, report, (output / "candidate.text").read_text(), repo_url,
        os.environ.get("SEKKA_PR", ""), repo_url + "/actions/runs/" + os.environ["GITHUB_RUN_ID"],
        api_review, (output / "api-review.text").read_text(),
    )
    (output / "summary.md").write_text(summary)
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as stream:
        stream.write(summary)
    print("Review material generated for", manifest["base"], "→", manifest["head"])


if __name__ == "__main__":
    main()
