# PR上のActions自己利用検証

2026-09-07。実装者自身による機能・表示確認。独立したレビュー効率の比較ではない。

## Swift差分なし: PR #17

[初回実行](https://github.com/KantoYamamoto/sekka/actions/runs/34042787030)はhead `e0c85c87fdcb364e1c749af5239e40eac1541454`で成功（2分51秒）。Swiftテスト39件、CLI/Gitチェック27件、要約テスト2件を実行。

ブラウザで件数表がすべて0、Swift差分なしの説明、変更ファイルへのPR diffリンク、折りたたみを開いた構造案内、比較SHAと自己評価の制約を確認した。artifactをCLIで取得し、manifest/text/compact/full/ordinary.diff/summaryの6ファイルのみで、バイナリを含まないことを確認。manifestのheadは対象PRと一致し、Swift限定ordinary.diffは空。

初回は旧ActionのNode 20廃止警告が1件出た。公式v7.0.1のSHAへ更新した[実行](https://github.com/KantoYamamoto/sekka/actions/runs/34043210247)（head `33797f95d77aad1b53ff77380ed64a7577b2713f`）で成功・警告0件・成果物のhead一致を確認してPR #17をマージした。

Scripts/ci_review.pyのリンクはGitHub自身のファイルアンカーと一致。新しい差分画面で初回のスクロールがずれたが、再読み込みで該当ファイルへの到達を確認した。PRリンクは最新の差分を開くため、過去の入力を厳密に読む場合はSHA付きmanifestとartifactのordinary.diffを使う。

## Swift差分あり: PR #16

[実行](https://github.com/KantoYamamoto/sekka/actions/runs/34043457912)はbase `b248ce9c97fe839f2f9bff14ae26946c2c63634f` → head `c743bb9cf55037388fd7f20091f85b60ef4d1321`で成功（全体2分22秒）。Swiftテスト41件、CLI/Gitチェック27件、要約テスト2件が通過。

ブラウザでSwift変更3件・構造観測5件・未観測ファイル1件・本体比較省略2件を確認。展開するとGitBatch追加、Inputsの変更、トップレベルテストの未観測表示が読める。Inputs.swiftのファイルアンカーから通常diffを開き、バッチ取得の変更を確認した。初回スクロール位置のずれはこのPRでも発生した。

artifactは6ファイル・バイナリなし。manifestのbase/head、ordinary.diffのSHA-256を照合した。text生成は2.418秒だが、ローカル測定とは環境・入力が異なるため高速化率を比較しない。構造案内から通常diffを読む流れは確認できたが、実装を知る本人の試用なのでレビュー効率の証明ではない。

## 残る表示上の制約

- ファイルリンクは最新PR diffを開く。過去の実行を再検証する場合はmanifestと保存されたSwift限定ordinary.diffを使用する。
- GitHubの新diff画面ではアンカー到達時のスクロールがずれる場合がある。再読み込みまたはファイル一覧から進める。
- text末尾のCLI例にrunnerの絶対パスが入る。ローカルでは`--path`を自身のcheckoutへ変更する。PR上ではファイルリンクを優先する。
- artifactは14日間保存。永続記録には比較SHAと観測結果を残す。

次はM2の未試用PRで通常diffのみとの比較条件を固定する。上記の表示上の制約は、その比較で追加操作が必要になった回数も記録する。
