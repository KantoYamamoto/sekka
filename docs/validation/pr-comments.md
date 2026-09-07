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

- [x] botコメントが1件作られる。
- [x] 折りたたみ内に罫線の階層が表示される。
- [x] ファイルリンクから該当diffへ進める。
- [x] 追加コミット後に同じコメントIDが最新headへ更新される。

fork PR経路・実際の失敗runからの差し替えは未実行。境界条件と失敗時更新は単体テストで確認している。

初回投稿: [コメント 5564944340](https://github.com/KantoYamamoto/sekka/pull/26#issuecomment-5564944340)。解析run `34082313292`、投稿run `34082494315` が成功。GitHub画面で折りたたみを開き、`├─` / `└─` / `│`の表示を目視確認。ファイルリンクからReviewGuide.swiftのdiffへ到達した。長い行はpre内で横スクロールする。ローカルSwift 43件・CLI/Git 27件・Python 10件も成功。

この記録の追加コミットで同一コメント更新を確認する。最終headと更新の証拠はPR本文とIssue #24にも残し、検証記録の更新だけで無限に再実行しない。

更新確認: head `bb37413221ae604df93bdcd5d3fb48b0a810a9ed`、解析run `34082584990`、投稿run `34082722889` が成功。APIでbotコメントは1件・ID `5564944340` のまま、本文の比較headと成果物リンクが更新されたことを確認。古いrun `34082313292` のdry-runは投稿をスキップした。これでIssue #24の実投稿・更新検証を完了。
