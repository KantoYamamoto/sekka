# 比較入力の全変更一覧: #34

2026-09-08。[判断0025](../decisions/0025-comparison-inventory.md)。Swiftの解析結果と比較入力の一覧を分け、CLI/JSON/PR rendererで同じinventoryを使う。

## 実入力と固定検証

bloom-timelapse PR #46の固定base `540a95c5bbf2a915fe2de37166dbc2c074a853c2` とhead `c57a5271a8c1d7ce9fbb12491ddac804f5ad9e4d` をローカルrepoで解析した。変更4パスがすべてnon-swiftとなり、Swift変更0件とは別に表示されることをtext/JSONで確認した。対象アプリをビルドせず、checkoutも変更していない。生出力はGit管理外に保存し、公開文書には複製しない。

- Swift 58テスト、CLI/Git 32チェック、Python 12テストが通過。
- 既存15境界probeと設計の問い6ケースも通過。
- 追加ケースは文書だけ・binary・カスタム除外・既定除外・リンク・削除・モードだけの変更・改行入りパス・64KiB以降の変更・表示上限・compact/full一致を含む。
- PR rendererは古いmanifestの一覧ではなくinventoryを使うこと、ファイル/観測/本体の単位、未信頼の区分文字列をHTMLとして埋め込まないことを確認した。

## 制約と統合

ディレクトリの対象は通常ファイルの内容で、既定除外パスとリンクは収集しない。Gitでは変更パスを収集するため両者の範囲は同一でなく、scopeへ明記する。追加の除外はSwift探索時には引き続き枝刈りし、比較一覧用の探索では変更を記録する。

全パスの保持と短い表示は別の問題。textの最大20パスやPRの一覧は初期の上限であり、今回の変更だけで重複や読む負担が解消したとはしない。#35で確認先・本体・構造の読み順を統合する。

## 自己利用・Actions

実装コミット後に旧評価器と比較し、通常diffと新旧結果を点検する。PRのjob summaryは新しいrenderer、投稿はdefault branchのrendererである。今回は新rendererの投稿dry-runと成果物をマージ前に確認し、マージ後の文書PRで実際のbot表示を確認する。実投稿の新表示確認が済むまで#34の運用確認を完了としない。
