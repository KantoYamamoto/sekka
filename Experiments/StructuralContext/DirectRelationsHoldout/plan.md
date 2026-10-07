親: #71。依存: #107 / PR #108完了（merge `ac70412`）。評価器は#108のSources tree `f07a5646391bcdd52d68093bbef233fc5d7f5f47`（code `58d85d1`）、binary SHA `c71d9882616173e152050efabf41f962ae78d07ccac11963692055b6db094f7a`、31対照のreceiptで固定。

## こういう場合はこうする
既読の必要関係へ直接到達できた後は、同じ例を再採点しない。両stage1へ同じPR説明と通常Swift diffを渡し、差分外の材料を案内する寄与と、普通のsource検索で得た判断を分けて未読比較する。

## What / Why
同形switch変更と既存窓口/利用側の関係という狭い契約が、実際のPRで既存構造の再考へ役立つかを調べる。0関係・入力不成立・問いの必要先未到達・問い自体の根拠なしを別に記録。位置案内/検索省略と構造再検討へ使われた根拠を区別する。関係数/出力サイズ/既読GRDBへの到達を成功条件にしない。

## 入力を見る前の選択
apple/swift-collections (Sources/) / groue/GRDB.swift (GRDB/)のclosed PR metadataをcreated-desc、number-desc、各最大40件。2026-10-06末UTCまでにmergedで、production prefix内にSwift変更がある最初2件ずつ。過去実験の入力/選択metadataに現れたPR（入力不成立・候補として検討したものも含む）を保守的に除外する。除外はswift-collections #721/#722/#723/#724/#725/#727/#728/#745/#747、GRDB #1850/#1852/#1858/#1864/#1869/#1876/#1884/#1885。タイトル/PRサイズ/switch有無/機械候補で選ばず、source/diff/query前にmetadata/filename/status/count・base/head・compareのmerge-baseを固定。固定beforeはそのmerge-base。filenameとprevious_filenameの両方でproduction Swift変更を判定し、PR詳細のchanged_filesと取得した全filesの件数/一意性を照合する。欠落やmetadata変化で適格性が不明ならそのrepositoryの選択を止め、後続へ差し替えない。変更pathのpatchはmetadata選択時に保存/表示しない。不成立/不足は結果として残し、都合のよいPRへ差し替えない。

## How / 終了条件
- [ ] plan/除外一覧/選択監査・前後refを、source/diff/機械出力閲覧前に固定。
- [ ] 対象をcheckout/build/test/scriptせず、固定tree/blobの全inventory/mode/size/SHAを検証。固定通常Swift diffの全hunk/gap/tailを検証。source/diff/生出力はignored。
- [ ] 固定binaryのJSON/text/allを二回実行し、終了コード/stdout/stderrを全bytes一致。失敗を正常0へしない。
- [ ] 履歴なし独立A/B各case。両stage1のPR説明/通常diffは同一bytes、Bだけ直接関係JSON/textを追加。commonsource閲覧前のcheckpointを凍結し、stage2で同じ全source検索を許可。互いの結果や開発経緯を渡さない。逸脱を記録。
- [ ] 必要先/問いの具体的な反復負担/別配置の条件/現配置の反対理由を位置付きで、根拠の出所（ordinary diff/source/tool）と実使用/無関係/不明へ分類。stage1資料SHA/両checkpoint/最終結果を独立点検。
- [ ] 結果に従い#12/#71/ROADMAP/検証記録を更新し、最終PRのActions/実Bot/成果物を確認。M3へ自動着手しない。

Why not: diff上位互換/設計警告を作らず、源泉の根拠と判断を分ける。旧#102のstage1非対称を繰り返さない。機械出力に合う入力選別や結果後のref修正/評価器変更を同じ比較へ混ぜない。

結果の分岐: 必要先への到達・配置再考への実使用が支持される用途だけ限定的統合を検討。必要な関係へ届かないなら未到達を分離し、別の決定論的根拠があるかを検討。範囲だけ増えた/寄与未支持ならM3保留。別の根拠もなくなれば用途限定/撤退を人間の判断事項として通知。

外部OSSはGET/readのみ。先方への投稿/Issue/PR/fork/その他変更は禁止。サブエージェントはレビューのみ。人間判断待ちなし。
