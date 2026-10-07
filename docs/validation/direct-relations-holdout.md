# #109: 同形switch変更を入口にした未見比較

**入力が成立しても構造再考への寄与が無い場合は、実装の完成を用途の成功に読み替えず、本番統合を止める。** 4pairの集計は完了、独立fact点検/最終PR点検は未完了。固定条件は[plan](../../Experiments/StructuralContext/DirectRelationsHoldout/plan.md)、保存資料の照合と再現は[実験README](../../Experiments/StructuralContext/DirectRelationsHoldout/README.md)。対象OSSへの投稿・変更、対象code/build/test/scriptの実行はしていない。

## 結果と解釈

評価器は#107のcode `58d85d1` / Sources tree `f07a5646391bcdd52d68093bbef233fc5d7f5f47`、binary SHA `c71d9882616173e152050efabf41f962ae78d07ccac11963692055b6db094f7a`。source/diff/出力を見る前に新しい4PRをmetadataで選び、compare merge-base/headを固定した。途中の不足入力や評価器変更による差し替えは無い。

| 入力 | 有効entries | 関係 / transition / unknown群 | 独立レビューの構造判断 | 機械出力の寄与 |
| --- | ---: | --- | --- | --- |
| [Collections #744](https://github.com/apple/swift-collections/pull/744) | 1,210 | 0 / 0 / 1 | A/Bとも既存module分離・共有処理の配置を支持、追加再配置の根拠なし | 必要先への入口/構造判断への実使用なし |
| [Collections #739](https://github.com/apple/swift-collections/pull/739) | 1,161 | 0 / 0 / 1 | A/Bとも既存iterator共有を確認、追加再配置の根拠なし | 同上 |
| [GRDB #1881](https://github.com/groue/GRDB.swift/pull/1881) | 341 | 0 / 1 / 4 | Aは現配置支持、Bは現配置を支持しつつ共通集約の改善という条件付きの問い | 問いは通常diff/source由来。機械は必要関係へ未到達 |
| [GRDB #1879](https://github.com/groue/GRDB.swift/pull/1879) | 342 | 0 / 1 / 4 | 後任A/Bとも共通schema判定から既存upsert処理へ届く現配置を支持 | 必要先/構造判断への実使用なし。担当交代の制約あり |

transitionは対応するswitchの形変化の件数であり、関係数とは違う。関係を出すには同じ形変化が複数の対応領域に必要。unknownは解析失敗でも「問題なし」でもない。正常0と入力不成立を分離し、全3,054 entriesのinventory/size/blob/SHAと通常diff全hunk/gap/tailを照合した。JSON/text/default/allの終了コード/stdout/stderrは各二回一致し、形詳細の省略は0、default/allも同一bytes。

この標本では現在の案内に実用上の根拠を得ていない。**0関係だけから、4PRが悪い設計、問題がない、目的が不可能、Sekka全体の撤退が必須、とは判断しない。** 追加の統合が不要という判断も目的に沿うが、今回はその反対材料も普通のsource検索から得ている。件数・圧縮率・既知GRDBへの到達で埋め合わせない。

## 普通のsource検索で必要になった材料

以下は実際のレビューに必要だった位置の例であり、全必要先の正解集合やrecallではない。便利な周辺文脈と網羅未達を別に扱う。

- Collections744: Aは `Sources/ContainersPreview/Extensions/RigidSet+Extras.swift:97/125`、`BasicContainers/RigidSet/RigidSet+Insertions.swift:125/186`、`SpanPreview/OutputSpan+InputSpanHelpers.swift:25/38`、Bは `InternalCollectionsUtilities/LifetimeOverride.swift:35`、`Span+Extras.swift:53`、`OutputSpan+Extras.swift:100`、`Strideable+LimitHelpers.swift:29`。いずれもafter側の差分外の未変更宣言。既存の共有・package可視性を読む材料で、実callee/全buildの解決ではない。AのHashTableメンバーはafterのみの読取でbefore全文照合未実施。protocolの条件/header、非Swift設定部分は宣言全体とは分ける。上位CMake/未変更test設定がpacketに無く、module配線全体は未確認。
- Collections739: A/Bは after `Sources/BasicContainers/RigidSet/RigidSet+Iterable.swift:30/44/92`、`UniqueSet/UniqueSet+Iterable.swift:22/36`をbeforeと照合し、既存のiterator共有を確認。残るRef生成位置と条件もsource検索から得た。protocol本体、`checkContainer`、compiler lowering/旧OSリンクは未到達・未実行で、残存Refを回避漏れと断定しない。Aが必要とした `_copyContents` をBは便利文脈とした違いも残す。
- GRDB1881: after `GRDB/Core/DatabaseRegion.swift:144` の既存union、`:377` のTableRegion.union、`StatementAuthorizer.swift:35/73`、`Statement.swift:135`、`Database+Statements.swift:36/99/382`、識別子の等価/hash、既存SQLテストへ普通の検索で進んだ。union144は宣言全体がhunk外、TableRegion.unionは末尾だけcontextに見える。formUnion169の**本体170–171は既にcontext**だがheaderはhunk外で、これを差分外の新発見として加点しない。TableRegion全体は変更されており、未変更memberと型全体を混ぜない。
- GRDB1879: 後任A/Bは after `GRDB/Core/Database+Schema.swift:577` の既存rowid判定、`:412` の主キーcache、`:1704` のtableHasRowID、`Record/MutablePersistableRecord+Upsert.swift:448/527` の既存共通処理へ到達。未変更宣言がhunk外にあり、局所例外をupsert各所へ追加せず既存schema判定で直す現配置を支持する。rowIDColumn1678は説明が変更された宣言の本体部分で、宣言全体未変更とはしない。旧SQLiteの判定制約とINTEGER主キーの競合更新未検証を留保し、helperの判定方式の不足をowner再配置の必要性と混ぜない。

## GRDB1881の問いは機械の成功ではない

Bはafter DatabaseRegionの `canonicalTables:205`（before181）、static `union:494/500`（before458/464）という、未変更かつhunk外の既存利用を追加検索した。Aはこれらを必要先として扱っていない。判断差を多数決やBの優位性で消さない。

- 関係: 新insert174/181→private TableRegion397/402と、既存formUnion169→union144→TableRegion.union377を同じ領域型内で比較する。canonicalTables211とstatic unionは汎用の合成を繰り返す。
- 具体的負担: 表が増える入力では汎用unionが増えた辞書を繰り返し列挙・生成する。新しい単一列/全表向けの操作は、既存の行制限を持つ領域をそのまま追加するAPIではない。特殊操作を更に増やす案と汎用合成を改善する案が比較対象になる。実利用で支配的な負担かは未測定。
- 別案の条件: formUnion/TableRegionの変異合成へ改善を寄せ、unionはコピー後に利用する案。ただし全DB、nil列/行、行制限、コピー独立性、識別子等価とprepare性能を維持できることが条件で、成立は未検証。
- 現配置の反対材料: SQL読み取りの狭い入力を直接扱い、一時領域の構築も省ける。ルールを既存領域型に置き、汎用演算の影響を避ける現配置は合理的。強制的な変更要求や、重複規則が実害を生むとの断定にはしない。

この関係は同じswitch形変化が複数あるという契約の外にある。既知例に合わせてmatcher条件を足す前に、どの根拠なら決定論的に表現できるか、旧減少call方式でも得られなかった理由は何かを診断する。

## 比較上の制約と次の判断

両stage1へ同一bytesのPR説明/通常Swift diff、Bだけ固定JSON/text。両checkpointをsource閲覧前に保存し、stage2は同じpacket内のsource/完全diff検索を許可した。全8材料とcheckpointのhashを照合した。包装scriptの初回版差は材料一致を確認して保存し、全材料を同じscript版が作ったとしない。stage2の非Swift diffは両groupに同時に許可した追加素材で、stage1の発見へ帰属させない。

GRDB1879は中断後にA/Bとも後任へ交代。固定stage1を書き換えず、別担当がそれを出発点として追加検索した。第4pairを同一担当の継続比較や効率の効果量として扱わない。レビューは検索した集合の静的所見であり、全ソース読破・実callee解決・実行テスト成功の保証ではない。

Bのunknownは4件とも本体未閲覧/判断不使用と記録。必要先の根拠がなく読取を見送ったのであり、全位置の無関係を証明していない。実行の整合receiptは暗号署名された実行証明ではない。raw素材/レビューはignored、公開metadataにhash/位置/出所だけを残す。

`--all`はdebug binary/2並行jobsで一回約52〜97秒。レビュー時間・release性能と混同しない。時間/トークン/負担の改善は測定していない。現在の方式を本番/M3へ進めず、結果独立点検後に次の診断を一単位だけ分解する。別の決定論的根拠まで尽きた場合に用途限定/撤退を人間へ判断事項として通知する。
