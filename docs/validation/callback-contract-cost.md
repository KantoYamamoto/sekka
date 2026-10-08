# callback契約の拡大と、既存利用側の適応

2026-10-08。[#122](https://github.com/KantoYamamoto/sekka/issues/122)の実source gateと[#124](https://github.com/KantoYamamoto/sekka/issues/124)の代替単位。**実装前に通常sourceを読んで固定した事実**。外部はGitHub GET/readのみ、checkout/実行/投稿なし。生source/manifest/選択履歴はignored `.build/callback-api-cost`。この標本は未見の有用性試験ではない。

## 元仮説の終了判断

最大二つのSwift候補を、detector出力を見る前に読んだ。

| 入力 / 固定base → head | source上の結果 |
| --- | --- |
| [Maple #3740](https://github.com/zubair-io/Maple/pull/3740) `049e1dd09bf673aac62cfe08df11723d78693c90` → `803b3a0b9fb53c766e946a05503fb5cbf175575a` | PhotoGridはelementと取得されたframeを組み、LibraryGridは選択状態を分岐する。契約変更はあるが「同じcallbackを渡すだけの中間二型」の負担ではない |
| [voicelayer #160](https://github.com/EtanHey/voicelayer/pull/160) `77bd65d2842e78e601264dc3c4b8972a855da417` → `f4d0e7ada721f7de486805c77cc793f02a8e3030` | SettingsView:307/470のonSelectedTabChange型は不変。新引数はhistoryPlayback、542でStateへ反映。callbackの引数増加ではない |

Kallo #267はmetadata検索の誤ヒット（Flutter/TypeScript）なのでSwift二候補には数えない。podhaven #673等の予備metadataと、sourceを読んだ上記二候補を混ぜない。元条件の実例を得られなかったためcallback-probeの中継契約拡大は実装しない。未解析の候補を正常0/負例へ数えず、この探索だけから方式の一般有用性も否定しない。

## 別の観測単位を支持する事実

MapleのPhotoGridはPhotoGrid.swift:120/137からhead:131/149へ、保持field/明示initのonTapを `(Element) -> Void` から `(Element, CGRect) -> Void` へ広げた。head:184はelementとframeを合成し、LibraryGrid.swift:139/145は選択を分岐してframeを利用する。両型の役割を「無責務なバケツリレー」とは呼ばない。

同じAPIの既存利用側には、追加slotを `_` にする適応がある。次の五つは前後closureの元引数参照を正規化するとbody tokenが同じ、という手書き期待を実装前に固定する。トークン同一は挙動同一の証明ではない。

| 呼出側（前後とも同じ行） | 前 → 後のclosure引数 |
| --- | --- |
| AllSourcesTimelineView.swift:172 / AllSourcesTimelineMonthSection.mergedGrid | `cell` → `cell, _` |
| BrowseGrid.swift:394 | `asset` → `asset, _` |
| CloudSearchView.swift:189 | 暗黙`$0` → `asset, _` |
| CloudTimelineView.swift:206 / CloudTimelineMonthSection.cloudGrid | 暗黙`$0` → `asset, _` |
| CloudTimelineView.swift:231 / CloudTimelineMonthSection.mergedGrid | `cell` → `cell, _` |

SearchPhotoResultsSection.swift:67はdirect function referenceからclosureへの変更なので、五つのbody比較へ含めない。PhotoGridの四previewとBrowseGrid:283は元から空bodyなので「元の処理が維持された利用側」の根拠へ含めない。取得inventoryは前後各八Swiftファイル、全PR/全利用側を保証しない。固定SHA/path/byte hashと期待位置は[入力manifest](../../Experiments/DependencyRelay/ContractMaterial/input.json)に保持する。

## 実装前の成功状態

```text
共有callbackの引数追加が、追加値を捨てる既存利用側へ波及
├─ PhotoGrid.init(onTap:)  (Element) -> Void → (Element, CGRect) -> Void
├─ 既存の五closure: 追加slotは `_` / 元引数参照を正規化したbody tokenは同じ
│  └─ 前後のAPI/closure位置から通常sourceへ戻れる
└─ 比較: 単一のevent payloadでcallbackの引数数を固定する余地
   期待: 今後metadataを追加するとき、不要な値を捨てる利用側のarity適応を切り離せる
   条件: 今回も将来もpayload契約・geometry取得時点/座標系・所有/Sendableを保つ
   反対理由: 初回移行が必要。一度だけの追加なら現在の単純なAPIが妥当
   不明: callee/型/挙動の同一性、変更の因果、全利用側、将来の拡張要求
```

これは「event payloadへ必ず変える」という診断ではない。現APIと `onTap: (GridTap<Element>) -> Void` の比較材料を一つにまとめる。metadata追加時に既存callsiteのclosure引数数まで合わせる理由があるかを問う。payloadに変えるだけで今回の変更量が減る、追加metadataをすべて独立進化させられる、設計負債を検出できた、といった主張はしない。

## 検証結果

実装前の独立source/scopeレビューは元条件不成立と五closureの事実を照合した。payloadだけに誘導せず、既存一引数入口を保ち、frame付き入口/adapterを別に設ける案も比較する。旧callerのarityを保つ利点と、入口二重化/どの通知を何回呼ぶかの契約の負担がある。

### 機械取得と独立コードレビュー

`contract-probe`で期待した五closure/API init位置を取得。前後16sourceのbyte/hashをmanifestと照合し、JSON/textを各二回実行して全bytes一致。固定inventory hashはbefore `827618667caf8daf62767e4fa55cebcc0922128e58f0e5b99e855f3711b5b5f4`、after `5c9645fa240059edcb067c5aeff6c9ee1f77a13b7f54f88b13e86ec314a619af`。

自作controlsはnamed/implicit/分岐の三caller、空body除外、現API/payload/adapterの三比較案、15負例、5入力失敗を全bytes二回一致で確認。before/after fixtureはSwift6 typecheck。共有reader抽出後のcallback 16負例/4入力失敗と先のconstructor 13負例/parse失敗も合格。

独立codeレビューは暗黙のcatch変数errorを元callback引数と誤認する反例を確認した。catch/局所typealias/protocolをunsupportedへ寄せ、反例controlを追加。独立再確認で反例0と主positive三件/固定Maple五件の維持を確認した。外部sourceは読解/解析のみ。

LibraryGridとSearchPhotoResultsSectionのcallはtrailing closure未対応として前後のUnknownに残る。direct referenceのbodyを機械比較したとは扱わない。macro-generated previewは範囲外として省略。Unknownを全不変APIへ大量に再掲せず、適格な拡大APIについてのみ出す。出力の範囲を明記して全利用側の数と誤認させない。

### 初読reviewerの通常資料との比較

実装者には既読の八source。A/Bは独立した初読reviewerで、同じ890行の通常diffと前後full sourceを読む。Bだけ固定candidate textを追加。目的はPR受入前の境界再考で、最大二つの問い/対案/現配置の理由/不明を求めた。外部アクセス/target実行と、判断文書/他レビューの閲覧は禁止。生レビューは公開Gitへ入れない。

| 条件 | 得られた問い/根拠 | 追加資料の寄与 |
| --- | --- | --- |
| A：通常資料 | frame取得を全gridのtap契約へ広げる必要があるか。通常入口を保ち必要surfaceだけframe付き入口を選ぶ案。共有実装一本化は現案の利点。selection集合とlive frameの単一対象を同一視してよいかも問う | 五closure適応と直接参照のwrapperを通常diff/sourceから把握 |
| B：通常資料＋出力 | 同じ二つの問い。必要surfaceだけcontext-specific入口を選ぶ案と現APIの単純さを比較。将来metadata追加の根拠はなくpayload必須とはしない | 二引数化と五adapterの根拠整理/照合を補助。問いの新規性は小さく、selection対象の問いには寄与なし |

両者の根拠はhead PhotoGrid:149/185、PhotoThumbnailCell:386–402、LibraryGrid:132–145、BrowseGrid:325–327/394、各 `_` 位置。geometry取得の因果/性能や範囲外hero実装は機械もreviewerも証明していない。共通pinch基盤へ移す必要は示しておらず、LibraryGrid内に状態/スクロール補償を置く利点も述べた。

一件/二AI・既読の入力・問いを明示した課題なので、未見の有用性や通常の人間レビューの短縮へ一般化しない。通常資料だけでも同じ具体的別案に到達した事実を保持する。独立読者の結果と主担当の整理を区別する。

### 投資判断と残り

根拠付きのAPI境界比較へ繋げることはできた。単なる件数より具体的だが、機械なしでも同じ問いへ到達している。今の支持は既存契約の適応をまとめる補助で、本番統合や広い設計検出の合格ではない。新しい構文対応/別素材探索をこの結果だけで自動継続しない。

### 自己利用

本番コードは不変なので同じ現行評価器で `6033ce0 → 08d95fd` を比較。20観測/Swift変更6ファイル/本体未比較45。共有SourceInventory境界と新規型への案内は得たが、reader維持/正規化/一意pair/catch束縛/Python・CI統合の確認は通常diffで行った。新contract-probeも実際の自repo変更source inventoryで実行し、契約拡大0件。自作fixtureの三件をこのPR自身の検出と混ぜない。実装者の既知情報を持つ自己レビューであり、独立した有用性評価ではない。

### 完了と次の判断

[PR #125](https://github.com/KantoYamamoto/sekka/pull/125)を最終head `158cff2de1c809982b8c9aee9020549d88ff3982`、[Actions成功](https://github.com/KantoYamamoto/sekka/actions/runs/37714886140)、実Bot body=summary、18成果物/全JSON/ordinary diff hash・文字数/自作三adapter・三比較案を確認後、merge `3a1ccdb36f4b6f7f3842bac0386b34fd78921b74`。#124完了。成果物の三件は自作fixtureで、当該Sekka PRの検出ではない。

決定論的な実根拠付き比較は取得できたが、通常資料だけでも同じ問い/対案へ到達している。独自の問題発見/時間短縮/未見の一般有用性の裏付けはない。根拠整理の補助まで否定せず、[次の限定試用 #126](https://github.com/KantoYamamoto/sekka/issues/126)で実入力経路・表示へ接続する。

終了判断の独立レビューは、限定試用の着手までユーザー承認待ちにする必要が薄いと指摘した。目的を変えない撤回可能な接続は委任範囲であり、利益未確立は人間だけが決められる要件とは異なる。承認ゲートを取り下げ、ルールを増やさず実Git入力へ一単位を接続する。M3合格や通常提供の採用とは分ける。最終成功を根拠整理だけへ変更する、元目的を縮小する、全プロジェクトを撤退する場合に人間の判断を求める。

### #126: 実入力への限定接続

成功状態は実装前にIssue #126へ固定した。`sekka review`をGit refs・作業ツリー・ディレクトリ比較へ接続し、解析は`Packages/CallbackContracts`とstandalone probeで共有する。parserを603.0.1へ揃えても、保存済みMaple全JSON・二つのhash・API位置137→149・五caller位置は一致した。新しい検出ルールは追加していない。

ローカル検証はSwift 6.4/macOSで65 tests、39 CLI/Git checks、実reviewのGit/dir/working tree/空の片側/非Swift inventory/parse・count・BOM・size・引数失敗と全出力の二回byte照合、Python表示/投稿16 tests（先行投稿修正を含む）。Documents配下の生成xctestにFinderInfoが付いて署名失敗したため、`swift test --scratch-path /tmp/sekka-contract-cli-core`で成功確認した。対象アプリのビルドではない。

独立レビューでassume-unchangedのSwift変更がinventoryから消えるP2を指摘され、比較したraw sourceから補完した。入力上限を読込前へ移し、BOMの除去でhashが変わる境界もreviewのみ明示拒否した。修正後、同レビューがCLI対照・directoryのBOM/4MB超/20MB超・表示8 testsを再確認し、未解消指摘なし。旧diff/scanの入力契約は維持する。

自己利用はbase `3a1ccdb` → 実装head `699615c`、13Swift変更/41構造観測、API reviewは0候補/0 unknown。今回に対象callback拡大はなく、方式の失敗にも有用性の成功にも数えない。最終Actions/実Bot/20成果物/mergeは[PR #127](https://github.com/KantoYamamoto/sekka/pull/127)と[#126の完了記録](https://github.com/KantoYamamoto/sekka/issues/126)を参照する。実PRのapi-reviewは自作対照のcallback-contractと分け、0候補も保持する。接続できたことは配置再考への純増利益やM3合格の証拠にはしない。

初回#127 Actions run37718299874は成功/20成果物だったが、実BotにAPI欄がなかった。デフォルトブランチの旧投稿器が再描画する経路を見落としていたため、[0055](../decisions/0055-trusted-trial-publisher.md)の投稿bootstrapを#128/PR #129に分離。16Python対照・独立trust境界レビュー・Actions run37736990352成功・旧形式実Bot=summary・18成果物を確認し、merge `b4979a4b9eec43cd0c50a450102a8826522e31c3`。#127を追従し、最終headの新形式実Bot/20成果物まで確認する。解析/成果物の成功だけで表示完了としない。

接続実装後の独立投資レビューは、同方式への追加実装を支持する具体的根拠は現資料にないと評価した。一件で一般無益は断定しないが、不確実性だけで素材探索/構文拡張を継続しない。追加投資の保留は元目的を維持する委任範囲。根拠整理だけを最終成功にする、用途限定を正式な目標にする、Sekka全体を休止/撤退する判断は人間に残す。これに合わせ、次の実装Issueを自動追加しない。
