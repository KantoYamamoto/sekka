# 別の固定4PRでの差分外案内比較（#95）

**今回も、本番統合を支持する根拠は得られなかった。** 新しい戻り値名/call経路は1件の既存producerを案内し、共通化を見送る文脈比較には使われた。ただし必要な確認先への増分利益や、局所修正の負担を見直す問いは成立していない。候補数と事実性を有用性の成功へ読み替えない。結果の独立点検は完了し、未解消の修正要求はない。

## 条件と再現材料

#93 / PR #94の最終source `a2172a0`、merge `f18508d`、保存binary SHA-256 `b403f914…5612a73`、Swift6.4 / SwiftSyntax604.0.0を固定。既知8PRを除き、同じ2repoの検索先頭40件からproduction Swift変更を含む最初の2件ずつを出力閲覧前に選んだ。repo自体は未見ではない。コメントだけの変更、0候補も差し替えていない。

全3,006入力をGit tree/blob・サイズ/SHAで照合。通常diffの65変更/381 hunk・path/status/mode・未記載gap/tailを前後sourceへ照合し、空/部分diffを拒否した。独立計画点検の修正後、7有効/11不正の合成対照も通過。JSON/text各二回のexit/stdout/stderr全bytesは一致。解析失敗と上限省略は全件0。

各caseで履歴なしA/Bを使用。stage1は同じPR本文→Aは通常diff、Bは固定案内。両checkpointの保存/hash確認後に同じdiff/before-after sourceを開放した。共有workspaceの閲覧指示による分離でありOS隔離ではない。担当差を含み、時間/token/人間の費用削減は測定していない。利用上限の中断後も同じ条件で再開した。

統合担当は比較開始前に、metadataの確認時に集計JSONの先頭10,000文字を誤って読んだ。この露出を記録し、独立担当にはその抜粋・所見を渡していない。統合担当自身を独立レビュアーとはしない。

固定ref・選択/実行・段階hash・位置別分類は[ResultHoldout](../../Experiments/StructuralContext/ResultHoldout/README.md)。第三者source/本文/diffと生レビューはGit管理外。hashから当時の本文/レビューを復元できるとはしない。対象OSSへはGET/readだけで、checkout/build/test/scriptや投稿・変更はしていない。

## 結果

配置の問いには、位置/関係、具体的な反復負担、別配置/成立条件、現配置の支持理由/不明という四つの根拠を要求した。挙動確認、候補の存在、一般的な改善論だけは合格としない。

| 固定PR | 全経路の宣言候補 / 根拠entry / 新経路entry | A: 通常diffと検索 | B: 案内と同じ資料 | 判断 |
| --- | ---: | --- | --- | --- |
| [Collections723](https://github.com/apple/swift-collections/pull/723) | 7 / 12 / 0 | 削除される旧経路から既存copy helperへ進み、入力供給の責務を比較する限定的な問い。四条件を条件付きで記録 | gap修復helperは挙動確認に使用。追加再配置の負担・別配置の根拠は認めなかった | 必要な共通先例は機械未到達。Aの問いをSekkaの成果としない |
| [Collections721](https://github.com/apple/swift-collections/pull/721) | 0 / 0 / 0 | 6件の文書名と引数名を照合。追加再配置の根拠なし | 同じ判断。本文由来の確認先は機械の案内ではない | 文書だけの変更。0候補を正しさの保証にも成功にも数えない |
| [GRDB1852](https://github.com/groue/GRDB.swift/pull/1852) | 3 / 3 / 1 | 既存DAOの方針判定・空更新経路を支持。再配置の根拠なし | Insert producerとの比較を文脈/反対理由に使用。必要先への増分利益なし | 新経路のみ1件は関連するが必須ではない。構造目的は未支持 |
| [GRDB1850](https://github.com/groue/GRDB.swift/pull/1850) | 0 / 0 / 0 | platform条件、bridge、provider、query APIの差分外sourceを確認。再配置の根拠なし | 同じ種類の必要先は存在したが機械未到達。再配置の根拠なし | 正常0であって、差分外の必要先なしという意味ではない |

### どの根拠に案内が使われたか

Collections723のBは未変更の`RigidArray._closeGap(at:count:)`を初期案内から読み、部分初期化後の状態に関する静的確認へ使った（2entry/1宣言）。配置再検討の四条件には使われていない。Aが構造の問いに使った`BorrowingIteratorProtocol._copyContents(into:)`は、after `Sources/InternalCollectionsUtilities/BorrowingIteratorProtocol+Extras.swift:37`。削除されるbefore `RigidDeque+Container.swift:451`等の呼出しから検索で得た。短い入力spanを反復する処理と各操作の手書き処理、既存helperの利用可能条件/個数検査を比較しており、単なる反復数の主張ではない。型検査・lifetime・性能は未実行、局所修正でも直せるため構造変更を必須としない。Bはこの問いへ到達しなかった。担当差を因果的な効果や見落とし率へ換算しない。

GRDB1852の新経路はafter `GRDB/Record/MutablePersistableRecord+Insert.swift:641`からの既存producerを案内。target本体はdiff/body外で、Bはstage1に比較先として挙げ、stage2でInsertとUpsertのrowID取得元の違いを読んだ。同じ成功情報のconstructor表記はbeforeにもあり、今回その反復が増えたわけではない。比較を共通化の反対理由に使った事実は残すが、必須先・新規問題・成立した構造問いへの増分利益とはしない。新経路のみ/既存のみ/両方/不明を分け、今回の候補は新のみ1entry・既存のみ14entry、重複/不明0。

### 誤接続と未到達

Bがsourceで棄却した同名候補は5entry。Collections723ではRangeのprefix/suffixに対するsegment型の候補2、bufferのdeinitializeに対するsegment型の候補2。GRDB1852では配列のcontainsに対するCursorの候補1。索引内の同形宣言1件を実calleeの一意性へ読み替えてはいけない。候補としてunknownを伝えても、不要な読取がなくなるわけではない。

GRDB1852の必要先は`ColumnAssignment.sql`/`noOverwrite`、`DAO.makeStatement`、`PrimaryKeyInfo.columns`、encode由来の`PersistenceContainer`等で、機械targetにはない。Collections723にもcopy helper、deinit、gap/初期化の必要先が残る。GRDB1850のimport/条件変更とtestの型注釈には必要なsource確認があるが、今回のproduction関数入口からは届かない。Windows条件が変わるbodyは、tokenが同じでも適用範囲まで未変更とは数えない。これらは担当が実際に使った範囲であり、全必要箇所の正解集合やprecision/recallではない。

## 次の判断

M2を継続し、M3/本番統合は保留。新しい候補経路を便利と称して積む前に、「afterのcallから探す」という検索方向で取りこぼした必要先へ戻る。次の[#96](https://github.com/KantoYamamoto/sekka/issues/96)は、beforeで減ったcall表記から両版に残る未変更の窓口候補へ進む原因診断。Collections723は既知の原因診断だけに使い、修正後に未見の成功へ数え直さない。

旧#66の参照減少/残存は、一意対応callerの減少表記→別の残る利用先を探した。今回必要だったのは削除caller→残る宣言そのものであり、その違いと同名SDK誤接続を最初に点検する。案内の出力だけで責務や根本改修の必要性を断定しない。次は原因診断の1単位だけを分解し、事実性/不要候補/必要先への到達が弱ければ実装せず方式を戻す。人間の判断待ちはない。

## 完了確認と限界

独立結果点検は全3,006入力/65変更/381 hunk、四つの資料開放/8初期checkpoint、queryと新旧帰属/B実使用を含む6,260検査とsource根拠照合を実施。7有効/11不正の自作素材対照も通過。Aの条件付きの問い、Bの非成立、新resultの非必須、5同名棄却、公開metadataにbody/tokens/生レビューがないことを確認した。[点検receipt](../../Experiments/StructuralContext/ResultHoldout/independent-review.json)。

独立担当は当時のstderr二回分やremote/Git object結合、閲覧の実操作を再生監査していない。型/callee/active条件、対象build/test/lifetime/実行/性能も未検証。統合担当は自分のGit objectからsource head→package tree/lockfileの一致を追加確認した。hashと保存証拠の整合性を、他の保証へ広げない。記録PRの必須Actions/実コメント/10成果物とmergeの完了状態は[PR #97](https://github.com/KantoYamamoto/sekka/pull/97)に残す。
