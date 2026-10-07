親: M2 #71 / 全体方針 #12。依存: #111 / PR #112完了（merge f2c65cc、最終Actions/実Bot/12成果物確認済み）。旧同形switch方式は凍結。

## こういう場合はこうする
新しい入口が既読の必要関係を表現できたら、細かなruleを増やす前に別入力を固定し、案内が既存構造/代替案/反対理由の検討へ使われるか、小さく比較する。

## What / Why / Why not
記載状態→操作→既存利用の試作は既読GRDB1881の必要先へ候補到達した。一方、別receiverの同名callや余分な操作も含む。候補数や既知到達を有用性とせず、普通のdiff/source検索に対する案内の寄与と候補負担を調べる。追加scope、意味解決、閾値調整、高速化、配布を先に行わない。結果に合うsourceや機械候補で入力を選ばない。

## 閲覧前に固定する比較
- #111の最終source/依存/controls receipt/binaryを固定。source/binaryが変われば同じ比較を継続しない。
- 新しいrepository `jordanbaird/Ice`（production `Ice/`）と `sindresorhus/KeyboardShortcuts`（production `Sources/`）。過去比較で使ったrepositoryの再選択を避け、アプリとlibraryで一件ずつ。今回だけ2件の限定診断であり一般的な効果の推定ではない。
- 各closed PRをcreated-desc/number-desc最大40件、2026-10-06末UTCまでmerged、production prefixにSwift変更がある最初1件。タイトル/サイズ/候補で選ばない。ファイル名/status/countとbase/head/merge-baseをGET metadataで固定してからsource/diffを取得。metadata変化/欠落/上限で不成立ならそのrepositoryは停止、後続へ差し替えない。before=固定compare merge-base完全SHA、after=固定PR head完全SHA。renameはfilename/previous_filenameのどちらかがproduction prefix内のSwiftなら適格とする。
- 検証済み素材取得/差分照合を再利用。全対象source inventory/blob/size/SHAと普通diffのhunk/gap/tailを検証。機械inputは各sideのproduction prefix配下全Swift。stage1は固定対の全Swift diff（production外のSwiftも含む）、stage2は両側production Swift＋全変更file＋LICENSEの検索可能packetと全通常diff。未変更の非Swift設定/文書/production外sourceは含めず、その不足を両担当へ同じ条件で伝える。A/Bは同じmanifest/素材hashを使う。対象checkout/build/test/script/投稿なし。source/生レビュー/機械rawはignored。
- fixed binary JSON/textを各2回、exit/stdout/stderr一致。Bへ渡す追加資料は罫線textだけ。JSONは事実性の点検用とし、Bへ二重に渡さない。出力制限/失敗/正常0を別に記録する。
- 履歴なし独立A/B各case。両stage1へ同じPR説明とSwift diff。Bだけ同じ段階でtext案内を追加。両checkpoint保存後、stage2へ同じ検索可能source/全通常diffを開放。同caseの担当を継続し、交代/逸脱は比較制約とする。互いの結果や開発経緯を渡さない。Bの寄与は実際に渡したtextの位置/candidateとcheckpoint・最終根拠に限る。JSONのみの詳細はBへ帰属せず、fact点検/他担当の所見を両stage2終了まで返さない。
- 必要な差分外位置/案内の実使用/不要な候補/欠落、普通diffとsource由来の問い、別配置の条件、現配置の反対材料、根拠の出所を分けて保存。実行時間をレビュー時間と扱わず、独自発見や速度改善を数値から推測しない。

独立protocol初稿のP2二件（固定対/scope、機会不在の扱い）をこの本文へ統合した。修正後点検と評価器の固定metadataは公開plan/freeze、経過はIssueコメントへ残す。

## 一PR単位の終了条件
- [ ] protocolと最終評価器をsource/diff閲覧前に固定し、独立protocol点検。
- [ ] 2選択のmetadata/refs/素材/機械出力の照合。不成立も保存し、差し替えなし。
- [ ] 両stage1/両stage2の独立レビューと位置/露出/出所/実使用を集計、独立fact点検。
- [ ] #12/#71/ROADMAPへ方針を統合し、PR/Actions/実Bot/成果物確認。

## 結果の分岐
案内が必要な差分外の関係へ届き、構造の比較へ実際に使われた例があれば、その用途だけ次の判断へ進む。両stage2終了後に具体的な構造別案を比較する機会があったかを位置/理由付きで記録する。機会なし/入口scope外/資料不成立は利益未判定とし、機会ありで未到達/不要候補中心/実使用なしの場合だけそのcaseの否定材料にする。どちらでも選び直し/追加case/閾値調整をしない。2例とも機会がなければ、この固定2例では判定できず継続の具体的根拠は増えなかったと終了し、既読診断の根拠と併せて用途限定等を人間の判断事項として通知する。一般効果の否定や自動撤退を宣言しない。独立比較でも寄与が得られず別の具体的な決定論的根拠も残らなければ、用途限定/目的変更/撤退を人間の判断事項として通知する。M3や実用性合格を自動宣言しない。

制約: Swift6以降/決定論的CLI・Actions/runtime LLMなし。外部OSS GET/readのみ、先方に影響する操作禁止。サブエージェントはレビューのみ。人間判断待ちなし。
