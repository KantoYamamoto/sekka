# 0055: 表示変更は、実際の投稿器まで接続する

**方針：PRの成果物を権限付きBotが表示する場合は、デフォルトブランチの投稿器でバージョン付きデータを再描画し、先行接続後の実コメントまで確認する。**

- 日付：2026-10-08
- 対応：[#128](https://github.com/KantoYamamoto/sekka/issues/128)、親 #126 / PR #127

## What / Why

API境界の試行結果を、実PRのBotコメントにも表示する。PR #127のrendererと成果物だけを変えても、投稿器はデフォルトブランチの旧rendererを使うため欄が欠落する。解析・成果物・投稿の三経路を一つの完了条件として確認する。

## Why not / How

PR供給のsummary HTMLを直接投稿する案は採らない。既存の権限境界を守り、api-review.json/textをoptional versioned dataとして取得し、共通のescape/上限付きrendererへ渡す。片側欠落・重複・不正schemaは停止。旧artifactに欄は追加しない。

CLI/解析と分けた投稿bootstrapをmainへ先行mergeする。その後PR #127を追従し、同headの必須Actions・実コメント・20成果物を点検する。少数のbundle異常/成功投稿の対照と独立レビューを使う。CLIの追加実装投資とは別の接続不備の修正であり、有用性の証拠にはしない。完了記録は#128/#126に残す。
