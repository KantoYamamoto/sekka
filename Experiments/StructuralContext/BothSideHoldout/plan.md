# #102: 入力を読む前の選択条件

2026-10-05。#100 / PR #103の最終Actionsは確認中。この準備ではPR metadataとfilename/status/countだけを読み、source/diff/機械出力は読まない。比較は#100完了後。

## 選ぶ条件

対象はapple/swift-collections（production prefix Sources/）とgroue/GRDB.swift（GRDB/）。各repoのclosed PRをcreated-desc/number-descで最大40件取得し、2026-10-04までにmergedされたものから、#77/#87/#95のselected入力を除き、production prefix内のSwift変更を含む最初の2件を採る。PR sizeや機械候補の有無で選ばない。足りない場合/byte取得・parser非対応は結果として記録し、都合のよい入力へ差し替えない。変更file metadataのpatch本文は保存/表示しない。

選択監査と前後object refを凍結してからsource/blob manifestを取得する。全source entryのinventory/bytes/blob/SHAと通常Swift diffの変更範囲を照合する。対象checkout/build/test/scriptや外部投稿はしない。

## 比較と判断

Aは通常diffと全source検索、Bは同じ素材+Sekkaの既定位置一覧/全根拠。履歴なし独立担当へ段階別に渡し、まず必要先と不明、その後に配置の問いを記録する。親の開発経緯・既知copy先例・A/B間の結論は渡さない。

source位置に裏付けられた具体的な反復負担、別配置の成立条件、現配置を支持する理由が繋がるかを評価する。sourceで分かった事実と案内の寄与、必須/文脈/無関係、正常0/入力失敗/中断を分ける。候補数・圧縮率・時間だけで成功としない。runtime LLMなし、M3/本番保留。結果で継続/再設計/用途限定/保留を選ぶ。

rawはignored .build/both-side-comparison。評価器freezeはPR #103完了後に確定。人間判断待ちなし。
