# PRコメントの実投稿検証

**表示を変更した場合は、単体テストに加えてGitHub上の投稿・同一コメント更新を確認する。**

## 目的と選択

Issue #24 / PR #25で共通レンダラーとpublisherを導入した。default branchにworkflow_runが必要なため、導入PRはActions成功と実artifactのdry-run後にマージした。続くPRで実投稿を検証する。

`Examples/pr-comment/ReviewGuide.swift` は公開可能な合成入力。型・ネストしたenum・メソッドを持つ小さな例で罫線の階層を確認する。実アプリの入力を都合よく変更した有用性評価ではなく、投稿経路と表示の検査である。設計推奨や独立したレビュー効率の証拠にはしない。

## 導入時の証拠

- [PR #25](https://github.com/KantoYamamoto/sekka/pull/25): Python 10テスト成功。
- [Actions](https://github.com/KantoYamamoto/sekka/actions/runs/34081972599): 成功。head `4eaf90836f84ace5cc31b1f687df1d26c9a3b4df`。
- 同runのartifactをpublisherでdry-runし、head/base照合と出力生成に成功。投稿はしていない。

## 実投稿の確認項目

- [ ] botコメントが1件作られる。
- [ ] 折りたたみ内に罫線の階層が表示される。
- [ ] ファイルリンクから該当diffへ進める。
- [ ] 追加コミット後に同じコメントIDが最新headへ更新される。

fork PR経路・実際の失敗runからの差し替えは未実行。境界条件と失敗時更新は単体テストで確認している。
