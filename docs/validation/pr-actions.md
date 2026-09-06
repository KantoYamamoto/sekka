# PR上のActions自己利用検証

2026-09-07。実装者自身による機能・表示確認。独立したレビュー効率の比較ではない。

## Swift差分なし: PR #17

[初回実行](https://github.com/KantoYamamoto/sekka/actions/runs/34042787030)はhead `e0c85c87fdcb364e1c749af5239e40eac1541454`で成功（2分51秒）。Swiftテスト39件、CLI/Gitチェック27件、要約テスト2件を実行。

ブラウザで件数表がすべて0、Swift差分なしの説明、変更ファイルへのPR diffリンク、折りたたみを開いた構造案内、比較SHAと自己評価の制約を確認した。artifactをCLIで取得し、manifest/text/compact/full/ordinary.diff/summaryの6ファイルのみで、バイナリを含まないことを確認。manifestのheadは対象PRと一致し、Swift限定ordinary.diffは空。

初回は旧ActionのNode 20廃止警告が1件出た。公式v7.0.1のSHAへ更新し、最新headの成功と警告解消を確認してからマージする。

## 次の検証

Swift変更のあるPR #16で、要約から対象ファイルdiffへ移動できることと成果物の入力一致を確認する。結果はこの記録へ追記する。artifactの保存期間は14日であり、永続記録には比較SHAと観測結果を残す。
