# 0016: PRのチェック画面で自己利用を確認する

**方針：自身のPRを検証する場合は、テストと構造案内をActionsで実行し、通常diffと詳細を成果物から辿れるようにする。**

- 記録日：2026-09-07
- 状態：採用
- 経緯：Issue #15。ユーザーがGitHub ActionsでPRレビュー時の見え方まで確認するよう依頼。

## 目的・状況

ローカルのtextを読めるだけでは、PRで導入した際に確認先へ進めるか分からない。自分のリポジトリで実行し、実際の表示を点検する。

## What — 選ぶこと

pull_requestでテスト・CLIチェック・候補評価器によるレビュー資料生成を実行する。ジョブ要約に件数、PR diffのファイルリンク、展開可能なtextを表示し、通常diff/JSON/hashを14日間のartifactに保存する。

## Why — 選ぶ理由

PRのChecksから読む場所と詳細へ進める。Swift以外のファイルも一覧に含め、観測がないことを変更がないことと誤解させない。実際のホスト環境でビルドできるかも同時に確認できる。

## Why not — 別案を採らない理由

PRコメントを毎回投稿する方式は反復が増え、書込権限も必要になる。最初はジョブ要約とartifactを使う。全NOTEをannotationでばらまく方式はローカルで削減した反復を復活させるため採らない。PRのコードで作った評価器を独立した検査と呼ばない。

## How — 実現方法

[workflow](../../.github/workflows/pr-review.yml)はmacos-26 / Xcode 26.5、read-only token、完全Git履歴、固定head SHAを使う。baseとのmerge-baseを求め、[ci_review.py](../../Scripts/ci_review.py)が既存の自己利用スクリプトで資料を生成する。ソースをHTML escapeして要約へ載せ、ファイル数・text長を制限して完全版へ案内する。actionは取得したコミットSHAへ固定し、checkoutの資格情報は保存しない。

## 制約・見直す条件

PRコード自体をビルドするため自己検査である。別の対象アプリはビルドしない。artifactに評価用バイナリは含めない。外部利用での有用性検証や汎用配布のM3完了とは区別する。runner/toolchainの提供変更時は実行ログを確認して更新する。

## 根拠・確認

- [runner環境](https://github.com/actions/runner-images/blob/main/images/macos/macos-26-Readme.md)でXcode 26.5を確認。
- [ジョブ要約](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-commands#adding-a-job-summary)とartifactを利用。
- ローカルの要約生成テストに加え、実PRのActions・要約・artifactを確認して検証記録を追記する。
