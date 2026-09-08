# 0029: 未変更ファイルの条件コンパイル位置を完全版へ回す

**方針：compact JSONで変更を読む場合は、未変更ファイルの条件コンパイル位置を省略し、共通制約・省略数・完全版への経路を残す。**

- 記録日：2026-09-08
- 状態：採用
- 経緯：#38の固定入力比較。0005の短いJSONと0013の共通制約を組み合わせる。

## 目的・What / Why

PR #33の22 noticesがすべて未変更fixtureの#if位置であることを再現した。compactのnoticesは変更されたSwiftファイルの条件コンパイル位置と、全ファイルのその他の注意を保持する。省略した位置件数を`omittedUnchangedConditionalNoticeCount`へ出し、全分岐を読む共通制約はlimitationsへ残す。fullは従来の全位置を保持する。

解析の対象外と、解析したが変更されていないため詳細を省くことを混同しない。構文解析自体は省略せず、読取り・解析失敗も従来どおり停止する。

## Why not

全noticeを変更ファイルだけに絞ると、曖昧な型の照合など重要な注意を隠す。表示文言の検索による分類も採らず、既存のinternal conditionalHeaderを比較結果まで保持する。変更されたファイルの#if位置は、条件自体が変わらなくても残す。

既存型表記を一律に省く案・要求時のみ出す案も比較した。Intの再掲は負担だが、Logger/Findingの既存構造の手掛かりも消える。今回は0022の最大5件を維持し、次の未読レビューで寄与を確認する。型名の意味によるブラックリストや新しいフラグは追加しない。

## How・制約

DifferがNoticeの内部分類を保持し、CompactReportがcoverage.changedFilesと照合する。JSONへ内部分類は出さない。省略数は0なら項目を省く。textの共通NOTEは全位置を持つfullを明示的に案内する。新規のルール・意味解析・リスク順位は増やさない。

compactとfullでnoticesは同一ではなくなる。仕様へ差を統合し、その他の観測・coverage・inventory・full JSONの不変を検証する。分類できないnoticeは省かない。背景の条件位置が必要な利用者はfullを使う。

## 根拠

[比較結果](../validation/context-notice-noise.md)、NoticeScopeTests。出力bytesの減少とレビューの利益は別であり、独立した時間短縮の証明にはしない。
