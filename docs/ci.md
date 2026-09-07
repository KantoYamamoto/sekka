# CIでの利用とSekka自身の運用

## 自分のrunnerから実行する

Sekkaバイナリと比較元のGit履歴を用意して実行します。必要な履歴がないshallow cloneでは比較できません。

```sh
sekka diff origin/main --head HEAD --merge-base --format github
```

`--format github`はActions annotation形式です。この形式自体の実画面検証は未完了です。通常は観測があっても終了コード0。`--fail-on-findings`を明示した場合のみ構造観測で1になります。比較範囲の説明だけでは1になりません。解析失敗は常に2です。観測を設計の不合格として扱う運用は推奨しません。

## このリポジトリのPRコメント

[解析workflow](../.github/workflows/pr-review.yml)はread-onlyでPR版Sekkaをビルドし、テスト・CLIチェック・構造案内・固定probeを実行します。[投稿workflow](../.github/workflows/pr-comment.yml)はdefault branchのコードで結果を読み、現在のhead/baseを照合してbotコメント1件を更新します。古いheadの結果は投稿しません。

コメントとジョブ要約は同じレンダラーを使います。確認ファイルのリンクを先に示し、罫線付きの詳細を折りたたみます。長い行は横スクロールし、詳細表示は16,000文字に制限します。完全版のtext/JSON、通常diff、入力ID・評価器hash、probe結果はartifactへ14日間保存します。

テストや解析に失敗した場合、現在のheadに対応するコメントを結果更新失敗の案内へ差し替えます。APIの権限不足やartifact不整合などで投稿できない場合は投稿workflowのログを確認してください。

これはPR自身のビルドによる自己評価であり、独立した承認ではありません。実投稿・同じコメントの更新・diffリンクは[検証済み](validation/pr-comments.md)。fork PRでの実投稿と実際の失敗runによる差し替えは未実行で、境界条件は単体テストで確認しています。

## 別のリポジトリへ移す場合

このworkflowはSekka自身のビルド・テスト・Scripts配置を前提にしています。汎用Actionとしては配布していません。初回の投稿workflowはdefault branchに存在する必要があります。権限分離・対象照合・信頼できる投稿側コードの条件は[判断0019](decisions/0019-pr-comments.md)を参照してください。
