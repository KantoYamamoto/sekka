# PR上のActions自己利用検証

2026-09-07。実装者自身による機能・表示確認。独立したレビュー効率の比較ではない。

## Swift差分なし: PR #17

[初回実行](https://github.com/KantoYamamoto/sekka/actions/runs/34042787030)はhead `e0c85c87fdcb364e1c749af5239e40eac1541454`で成功（2分51秒）。Swiftテスト39件、CLI/Gitチェック27件、要約テスト2件を実行。

ブラウザで件数表がすべて0、Swift差分なしの説明、変更ファイルへのPR diffリンク、折りたたみを開いた構造案内、比較SHAと自己評価の制約を確認した。artifactをCLIで取得し、manifest/text/compact/full/ordinary.diff/summaryの6ファイルのみで、バイナリを含まないことを確認。manifestのheadは対象PRと一致し、Swift限定ordinary.diffは空。

初回は旧ActionのNode 20廃止警告が1件出た。公式v7.0.1のSHAへ更新した[実行](https://github.com/KantoYamamoto/sekka/actions/runs/34043210247)（head `33797f95d77aad1b53ff77380ed64a7577b2713f`）で成功・警告0件・成果物のhead一致を確認してPR #17をマージした。

Scripts/ci_review.pyのリンクはGitHub自身のファイルアンカーと一致。新しい差分画面で初回のスクロールがずれたが、再読み込みで該当ファイルへの到達を確認した。PRリンクは最新の差分を開くため、過去の入力を厳密に読む場合はSHA付きmanifestとartifactのordinary.diffを使う。

## 次の検証

Swift変更のあるPR #16で、要約から対象ファイルdiffへ移動できることと成果物の入力一致を確認する。結果はこの記録へ追記する。artifactの保存期間は14日であり、永続記録には比較SHAと観測結果を残す。
