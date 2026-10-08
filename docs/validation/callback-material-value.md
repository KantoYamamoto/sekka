# callback中継：素材選択と案内の寄与

2026-10-08。[#121](https://github.com/KantoYamamoto/sekka/issues/121)。実装追加なし。#119 / PR #120は最終head `4409c55`、[Actions](https://github.com/KantoYamamoto/sekka/actions/runs/37709315476)成功、manifest/実Bot=summary/16成果物を確認してmerge `5f9b63ca`。

## 別入力の探索

最大SwiftUI二候補を通常sourceから読んだ。機械出力を見て差替えず、検出器は両候補で未実行。

| 入力（base → head） | sourceから分かったこと | 評価での扱い |
| --- | --- | --- |
| [SwiftDecision-Examples #56](https://github.com/SoundBlaster/SwiftDecision-Examples/pull/56) `df426505` → `58e3d2c8` | speech content/共有fact Linkの抽出。新設型はmessage/fact/fontを受け取る。既存onDismissは残る | 当該callback中継増加の正例ではない |
| [pickture #19](https://github.com/0xDAFE/pickture/pull/19) `135098f7` → `8a1abbc1` | callback APIは増えるが、GridContentView:102–120/FilmstripView:314–321でsession操作/画像読込/結果反映closureを作りcellが呼ぶ。ContentViewはsessionを渡す。Sidebar/EmptyWorkspace/ToolbarはButtonで直接呼ぶ | 同じcallbackを通すだけの二段経路ではない |

source/manifestはignored `.build/callback-followup`。外部はGET/readのみ、編集/target実行/投稿なし。独立source/選択レビューも当該経路の見落としや結論の飛躍なし。探索は不成立、未見入力での配置比較は未実施。正常0の負例や一般的な有用性否定へ数えない。タイトルで部品抽出を探すだけでは、対象の負担を選びにくかった。

## 既読実例を初読reviewerで比較

別入力が得られなかったため、入力自体が既読である限界を保持し、[固定growth](stored-callback-relay.md)の案内寄与を一回点検した。A/Bは独立した初読reviewer。両者へ同じ通常diff（4,076文字）と前後のContentView/FeedContentScrollView四sourceを渡し、Bだけ固定callback-probe textを追加。実Issue/後の修正/判断文書/他の評価結果を渡さず、外部アクセス/target実行を禁止した。問いはView抽出の配置見直し、現配置の利点、具体的別案と成立条件。Bには追加資料の寄与も区別させた。

| 条件 | 得られた問い・案 | 限界 |
| --- | --- | --- |
| A：通常資料 | 棚の構成/タイトルとスクロール配置の境界。ContentViewでFeedShelvesViewを組み、generic FeedContentScrollViewへ渡す案。現配置は順序/空判定をまとめる利点 | sourceから再利用要求を確認できず、移設必須とはしない |
| B：通常資料＋出力 | 中継1→2が明示され、棚全体ではなくResumeShelfViewだけをContentViewで組み、両containerへitems→content factoryを渡す案。現配置は棚順序/余白をまとめ、再生状態をrootに保つ利点 | items契約/所有/identity/更新/snapshot条件の成立はsourceだけでは証明できない。owner未対応のUnknownは今回の配置判断に不要 |

根拠はhead Feed:60–65/84–119、Content:164–172/463、base Feed:60/67/80。Aもgeneric content案へ到達しているため、根本的な問いを追加資料だけが新たに生んだとは言えない。Bはcallback経路と末端だけの移設案を明確にしたが、中継が増えた事実は通常diffでも読める。操作追加によるAPI負担の実例は、この素材では確認していない。

reviewer自己申告はA約19秒、B約23秒。二名/一素材・ツールI/Oや実際の人間レビューを統制していないため、速度比較や時間短縮の証拠には使わない。sourceと生レビューはignored、公開記録は上の問い/位置/理由だけ。独立reader比較と主担当による結果整理を区別する。

## 投資判断

中継の取得と条件付き別配置の案内は成立した。未見入力の一般有用性、レビュー短縮、設計問題の確定は未支持。本番/M3は保留。深さや抽出だけを注意の根拠にせず、**同じcallback契約の変更で既存の中間二型も実際に書き換わった**場合の根拠を次の一単位[#122](https://github.com/KantoYamamoto/sekka/issues/122)にする。

今の記載経路を再利用し、開始/末端/中継field列が同じで引数数が増えた場合に限定する。因果や責務は断定しない。必要な明示依存/ownershipなら現配置が妥当、という反対理由も保持する。一般graph/型解決/historyや未適合例の個別構文対応を先に増やさない。この一単位が実負担と配置比較へ繋がらなければ、検出項目を増やして延命しない。
