# 0019: PRに読みやすい案内を1件ずつ更新する

**方針：PRで解析結果を共有する場合は、現在のheadを確認してbotコメント1件を更新し、確認先と解析限界を分けて表示する。**

- 記録日: 2026-09-07
- 状態: 採用
- 経緯: ユーザーがPRコメントへの出力と記号を使った読みやすさを依頼（Issue #24）。0016の「初回はコメントしない」を、この明示依頼により更新する。

## What / Why

PRコメントとジョブ要約を共通のレンダラーで生成する。📄変更・🧩構造観測・🔎構造観測なし・⏸比較省略を区別し、ファイルリンクを先に、全文案内を折りたたみに置く。人間が開く場所を選べることが目的。記号だけに頼らず日本語ラベルも併記する。

## Why not

pushごとの新コメントは議論を埋めるため採らない。✅/❌で設計の合否を判定しない。PRビルドへ投稿用tokenを渡さず、成果物中のMarkdownやコードをそのまま実行・投稿しない。ローカル用CLIのrunner絶対パスはコピーしても使えないため、画面の案内から除き、完全artifactは保持する。

## How

解析は従来のread-only pull_request workflow。投稿はdefault branchのworkflow_runで動き、default branchのPythonだけを実行する。APIのrun→PR→headとbaseを照合し、サイズを制限したartifactからmanifest/JSON/textだけをデータとして読む。textはHTML escapeし、escape後の長さも制限する。投稿直前にもheadを再確認する。

専用markerを持つgithub-actions[bot]のコメントだけを更新し、人間のコメントは編集しない。解析・テスト失敗時は古い成功結果を現headの結果として残さず、結果更新失敗と実行ログへの案内へ差し替える。forkのPRでも対象照合は必要で、artifactをコードとして扱わない。

## 導入と検証

workflow_runはdefault branchに定義が必要なため、最初のPRは単体テストとdry-runで検証してマージし、続く検証PRで実投稿・同一コメントの更新を確認する。これが終わるまでIssue #24は完了しない。初回マージだけで投稿機能を実証済みとはしない。

## 制約・見直す条件

ソース側の解析結果はPR自身のビルドによる自己評価。コメントは現在のheadを記載し、PRリンクは最新diffへ進む。head再確認と投稿はAPI上で原子的ではないため、比較SHAを必ず表示する。権限やartifact不整合で投稿できない場合はpublisherのActionsが失敗し、ログを確認する。独立したレビュー効率の証明には数えない。

## 根拠

- [GitHub workflow_run](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run)
- [publisher](../../Scripts/publish_review.py)、[テスト](../../Scripts/test_publish_review.py)
