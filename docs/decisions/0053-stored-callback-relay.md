# 0053: 実コードの中継単位から、次の試作を決める

**方針：実例が保持したcallbackをbodyで渡している場合は、constructor対応を広げ続けず、そのcallbackの記載上の経路と増えた境界を一単位で調べる。**

- 記録日：2026-10-08
- 関連：[#117](https://github.com/KantoYamamoto/sekka/issues/117)、[0052](0052-config-free-first-problem.md)
- 状態：実sourceで中継の増加を確認。次の取得単位を決定、解析実装はこれから。本番/M3は保留

## What / Why

0052の自作試作は新しい引数が二つの明示constructorを通る形を取得できた。しかしSwiftUIの実例は、保持したcallbackをcomputed bodyの子Viewへ渡す形だった。型/メソッド件数や全constructor対応を増やすことではなく、変更により中間のcallback受渡し境界が増えた理由と別配置を示すことを目標にする。

前の予備候補bloom-timelapse #56とswift-service-lifecycle #100は対象負担を確認できなかった。機能追加タイトルから選ぶ方法を止め、依存中継を具体的に述べた[Issue #29](https://github.com/Debiancc/bilibili_tv/issues/29)と修正[PR #31](https://github.com/Debiancc/bilibili_tv/pull/31)からsourceを照合した。作者の「7層」「40%」という説明は測定値として使わない。[確認位置](../validation/stored-callback-relay.md)に根拠を保存した。

この修正前には、`onResume`がFeedContentScrollView → ShelvesSection → ResumeShelfViewへ渡され、中間二型には当該callbackを呼ぶ記載がない。同リポジトリの履歴では、PGC channel追加のcommit `743c84a`がShelvesSectionを抽出し、中継を一段から二段へ増やした。中間型全体が無責務なのではなく、このcallbackについて配線の境界が増えたことが根拠。

## 欲しい成果（手書き。まだ検出結果ではない）

```text
記載上のcallback中継が1 → 2段に増えました
├─ FeedContentScrollView.onResume → ShelvesSection.onResume [追加された境界]
└─ ShelvesSection.onResume → ResumeShelfView.onSelect
   中間二型での参照は子への引数。末端にはonSelect(entry)の記載
   呼出側: ContentViewのclosure（元の状態を更新する確認先）

比較する案
   呼出側で末端Viewを組み立て、layoutにはcontentを渡す
   → 末端のaction/依存の追加を、中間のaction用APIから切り離す余地
条件
   layoutが供給するitems等の契約を安定させられること
   状態の所有・View identity・更新・snapshotの差替えを保つこと
   genericなcontent slotの複雑さが見合うこと
不明
   実callee/生成init/実行時のeffectsは解決していない
```

呼出側と末端の位置を添え、「中間の引数を増やし続ける」案と比較する。content factoryにも受渡しは残るが、末端actionを中間APIで個別に知る必要を減らす狙い。渡すitems自体の契約が変われば、依然として中間の変更が必要になる。移設が正しい/今回の行数が減るとは断定しない。

修正PRの実装はEnvironment上のPlaybackCoordinatorと一つのpresentationへまとめている。それは作者の選択であり、Sekkaが自動的に推奨する修正ではない。Environmentは設定位置・テスト・依存の見え方の確認が必要。[別の実相談](https://github.com/pointfreeco/swift-composable-architecture/discussions/3731)も、引数の回避とStoreの一度だけの生成を同時に要求している。中継除去だけでは生成/所有を解決できない。

## How / 次の実装単位

同じSwiftSyntax依存を使い、供給された前後source inventoryの一意なstruct、明示したconst function field、子への直接の名前付き引数、末端にある当該fieldの呼出表記を読む。初回は記載上の戻り値がVoidのcallbackに限定する。compilerの生成initや責務は推定しない。関連する字句衝突、macro/条件付き宣言、custom init等が対応を曖昧にする場合は不明とする。

複数ファイルの位置と入力hashを持ち、同じ開始field/末端field/型表記の経路を前後比較する。新しい中間型、または一段から二段への増加を出す。既に修正されたPRでは、記載上のfield/経路の削除を、実行時依存の消滅と区別する。余分な参照、変換、captureしたwrapper、同名shadowは単純中継としない。前後どちらかのread/parse失敗は部分結果を返さない。

0052のconstructor試作は保存された取得可能性の実験として扱い、この実例のために一般のconstructor/型/alias/graph対応を継ぎ足さない。本番CLIへは統合しない。最初は一経路の取得、意味を変えた最小の対照、この実変更での出力を確認する一PRに限る。自己利用と独立レビューで、機械で得た材料と通常読解による発見を分ける。

## Why not / 結果による分岐

- 一般の型/呼出解決は、今回の記載上の経路を示すための初回投資として大きい。未知を残す。
- callbackの数/深さだけで悪い設計とする方法は、明示的な配線の価値を無視する。増えた境界・当該callbackの用途・具体的な別配置を一緒に示す。
- constructor試作の未対応を順次埋める方法は、実例の本体に届かない。今回の入力から取得単位を置き換える。
- 同じ例で取得できても、一般的な有用性やレビュー時間短縮の合格にはしない。後の修正を知って選んだ事後診断であり、未見比較ではない。

この一経路が取れなければ広いgraphへ進まず、不足の理由と費用を判断する。取得できても、出力が「配線が増えた」だけにとどまり配置比較に使えなければ次機能を増やさない。
