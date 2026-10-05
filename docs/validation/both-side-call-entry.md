# 前後のcall表記から残る窓口への入口（#100）

**変更後だけの入口で必要な既存窓口を落とす場合は、前後の利用を共有索引で数え、旧位置と対応不明を一緒に示す。** [判断0047](../decisions/0047-both-side-call-entry.md)、[Issue #100](https://github.com/KantoYamamoto/sekka/issues/100)。既知4PRの実装再現であり、未見の有用性評価ではない。本番/M3は保留。

## 組み直したもの

旧MemberSpellingContextをCallSpellingContextへ置き換え、introduced（変更後member表記）とdecreased（selector総数減少）の根拠に分けた。WrittenCallSearchは前後call/宣言索引・caller対応・残る宣言の不変判定を持つ。Result経路も同じsearchを使う。別のAST readerや候補一覧、診断Pythonのruntime detectorを足していない。

減少側は索引関数bodyのmember/unqualified nontrailing表記を全部数え、前後各1宣言・同一の一意対応・字句header/宣言token不変・本文ありを必要とする。各出現はside、caller/call位置、確認できた反対側caller、対応状態、条件を保持する。selector総数の減少から特定のcall消失・rename/移行・実calleeを対応付けない。同名SDKが残ることも隠さない。

## 検出と表示の境界

初稿のCollections723は10候補中8件の詳細しか出さず、必要なcopy先例を上限で隠した。検索と詳細表示を分離し、既定の詳細外も`omittedContextIndex`へ全位置・根拠数を残し、textに一覧を出す。`--all`なら同じ適格条件の全候補/全根拠を読める。selector減少groupの位置は既定でも全件保持する。copy専用scoreや入力差し替えで見えるようにしたのではない。

全位置のJSONは長くなることがある。`--all`は省トークン用ではなく、上限に依存せず根拠を点検する手段。既定8詳細の並び順がレビューの優先度を意味するとも、候補の存在が再配置を勧めるとも言わない。

## 検証の範囲

own Git archiveのbinary source `d0772a6`で100 Swift Testing tests通過。独立指摘を受け、単一target内の根拠詳細省略にも`--all`を案内するcueを`d460007`で補い、100 tests/17 CLIを再確認した。索引/検索/JSONは変更せず、全4caseの全根拠JSON/textを一回ずつ実行し、先の二回一致した凍結出力と全bytes同一を確認した。現行CLI verifierは17対照で、入力失敗に加えて旧位置/対応不明・上限外位置・全根拠を確認した。診断構成と既存withdrawn-entry 37対照も通過。成功/失敗のexit/stdout/stderrを二回比較し、parse/readの部分成功を拒否する。localは前単位で確認したXCTest loader問題のため`--disable-xctest`、PRの通常CIは変更しない。

外部対象は#95/#96の同じ4入力。素材validatorが全3,006 source entriesのinventory/bytes/blob/SHAを照合してから、自分のCLIだけを実行した。凍結sourceの通常JSON、`--all` JSON/textの完全出力をそれぞれ二回比較し、一致した。対象checkout/build/test/scriptや先方への投稿は行わない。生source/出力/レビューはignored `.build/both-side-call-entry/`、公開はmetadata・位置・件数/hashのみ。[検証receipt](both-side-call-entry-checks.json)。

| 既知入力 | 全候補（宣言） | 全根拠（件） | 減少表記から残る候補（件） |
| --- | ---: | ---: | ---: |
| Collections723 | 10 | 16 | 4 |
| Collections721 | 0 | 0 | 0 |
| GRDB1852 | 3 | 3 | 0 |
| GRDB1850 | 0 | 0 | 0 |

全42減少selectorのうち、不適格38組と適格4組が#96の診断と一致した。適格4組は両側の宣言位置、全利用の位置/form/receiver表記hash/条件hashを照合した。copy先例は通常詳細の上限外だが位置一覧に残り、`--all`では旧利用4→0の全根拠を読める。gap helper（3→2）は挙動確認の必要位置へ交差する。一方でdeinitialize（23→22）のSDK等の同名と、mutablePtr（14→13）の必要集合外もそのまま残る。4候補すべてを有用と採点しない。他3入力で減少側の新候補は0で、全ての根本見直しへ届く方式とも言えない。

独立レビューは全3,006入力、42減少group、適格4組の前後81出現、全13targetの一意対応/header/token/ファイル不変を照合した。通常/全根拠の第三実行も保存JSONと一致。9 target/各12根拠の合成対照で省略一覧・全根拠・位置/caller/sideを確認し、単一target内の省略cue指摘は修正後に解消。未解決コード/境界指摘なし。固定58必要範囲との交差や公開hashも点検したが、交差をcoverage/semantic relevanceに換算していない。対象型検査・実行/性能・新しいレビュー利益・PR Actionsはこの独立点検の対象外。

## 自己利用と次の判断

本番Sekkaの自己利用はbase `af14520` → `d0772a6`。Swift変更11ファイル/31観測から、旧経路撤去、新evidence型、WrittenCallSearchの拡張、compare引数の追加へ進めた。比較本体6のうちtoken同一2、未比較10で、bodyの意味やcall検索の正しさは通常diff・対照・独立点検による。top-level CLI/test関数はfile diff入口として読む。自己利用を未見の有用性と呼ばない。

PRの最終Actions、実Botコメント/10成果物、merge状態はIssue #100とリンクされたPRに記録する。次は[#102](https://github.com/KantoYamamoto/sekka/issues/102)でこの方式/評価器を固定し、別の未読入力で独立比較する。必要な差分外先例へ届くことと、具体的な反復負担・別配置の成立条件・現配置を支持する理由が揃うことを別に評価する。利益が弱ければ本番へ統合せず、入口の関係単位を再設計する。
