# 実sourceで確認したcallback中継

2026-10-08。[判断0053](../decisions/0053-stored-callback-relay.md)の入力選択と事実の根拠。入力選択時の通常sourceによる読解と、その後の機械取得を分けて記録する。

## 選択と入力

Debiancc/bilibili_tvの[Issue #29](https://github.com/Debiancc/bilibili_tv/issues/29)が中間ViewのBinding/callback転送とrootの複数presentationを指摘し、[PR #31](https://github.com/Debiancc/bilibili_tv/pull/31)へ繋がる。Issue→通常diffの順に選び、新解析器の実装前にこの選択と必要位置を固定した。作者の主張をそのまま検証結果にはしない。

PR修正前base `f88ef7fdb7581d90a928ab62d6e56edefdfd756b`、head `182693c75e414d6f60cdb6fa20d19f0349547a55`の関連四ファイルをGitHub GETで取得した。中継を増やした履歴は、sourceを確認して[commit 743c84a](https://github.com/Debiancc/bilibili_tv/commit/743c84a72571fbb793eddd02dac067ea39bf38ea)に特定。base `bc7f1135a52d3cd0e307ee04090fcf6a28526526`とheadのContentView/FeedContentScrollViewを比較した。先の抽出commit 72b1d9e/5132e5eでは二段へ増えておらず、正例へ数えない。

入力とSHA256/選択理由はignored `.build/real-relay-scope/{selection,source-manifest,growth-selection}.json`。公開記録はref/path/lineと根拠のみ。外部sourceのcheckout/build/test/script実行や先方への書込みはしない。

## 増加前 → 増加後（通常sourceの照合）

| 記載 | base bc7f113 | head 743c84a |
| --- | --- | --- |
| 呼出側のcallback | ContentView:151でresumeToPlayへ代入するclosure | ContentView:171で同じ状態へ代入するclosure |
| FeedContentScrollViewの保持 | onResume宣言:12 | onResume宣言:12 |
| 子への渡し先 | ResumeShelfViewのonSelect引数:67 | ShelvesSectionのonResume引数:63 |
| 新しい中間field | なし | ShelvesSection.onResume宣言:87、ResumeShelfViewへ渡す:102 |
| 末端の保持/呼出 | ResumeShelfViewのonSelect宣言:431、呼出:443 | ResumeShelfViewのonSelect宣言:451、呼出:463 |

参照先：[増加前Feed](https://github.com/Debiancc/bilibili_tv/blob/bc7f1135a52d3cd0e307ee04090fcf6a28526526/bilibili_tv/Features/MovieFeed/Views/FeedContentScrollView.swift#L67)、[増加後Feed](https://github.com/Debiancc/bilibili_tv/blob/743c84a72571fbb793eddd02dac067ea39bf38ea/bilibili_tv/Features/MovieFeed/Views/FeedContentScrollView.swift#L63)、[新しい中間](https://github.com/Debiancc/bilibili_tv/blob/743c84a72571fbb793eddd02dac067ea39bf38ea/bilibili_tv/Features/MovieFeed/Views/FeedContentScrollView.swift#L87)、[末端](https://github.com/Debiancc/bilibili_tv/blob/743c84a72571fbb793eddd02dac067ea39bf38ea/bilibili_tv/Features/MovieFeed/Views/ContentView.swift#L463)。

当該fieldの中間での参照は、上表の子への引数としての一箇所ずつ。中間Viewは他のmodel/表示/選択の処理も持ち、型全体を「ただのバケツリレー」とは判定しない。callbackの引数labelがonResume→onSelectへ変わっているため、label一致だけの検索では足りない。

これはlayoutの抽出に伴う一つの配線境界の追加。今後このcallbackの契約や関連actionが増える場合、末端/呼出側に加えて中間のfield/受渡しも確認する必要がある。過去の変更回数や時間短縮は測定していない。

## 後の修正と代案

PR #31のbaseでは同じ二段経路が残る（Feed:12/68、ShelvesSection:92/107、ResumeShelfViewの呼出ContentView:349）。headでは中間のonResume fieldが削除され、末端がEnvironmentのPlaybackCoordinatorを呼ぶ（ContentView:325/337）。rootはplaybackの二つのfullScreenCoverから一つへまとめるが、DEBUG用の別coverは残る。「全coverが一つになった」とは扱わない。

作者のEnvironment/Coordinator案とは別に、呼出側で末端Viewを組み立て、layoutへcontent slotを渡す案も比較できる。これは手書きの設計案で、対象を変更/実行して成立を検証したものではない。itemsの供給、View identity、状態の所有、snapshotの差替えを保つ条件と、genericなslotの費用がある。

## 既存試作との違い / 投資判断

0052のrelay-probeをPR #31の前後FeedContentScrollViewに実行すると、両側とも明示initがなく未解析、候補0。入力選択後の既存方式の限界確認であり、正常負例や新方式の成功ではない。

必要なのは多ファイルの明示closure fieldとbody内の直接受渡し・末端呼出の照合。明示constructor、所有期間、実calleeの一般解決を先に実装する必要はない。一経路の取得へ実装を限定した。反例で誤った中継を出す/別配置に繋がらないなら、scopeや件数を増やして延命しない。

独立のsource/計画レビュー一回で、前後の各位置・中間の当該fieldの参照・末端呼出・修正後の状態と、条件付きcontent slot案を照合。上位指摘なし。一経路の機械取得へ進む投資は妥当とされたが、実装や一般的な有用性の合格ではない。

## 機械取得（#119）

`callback-probe`でgrowthの二ファイルずつを比較し、`FeedContentScrollView.onResume`から`ResumeShelfView.onSelect`への中継が1→2となる一件を取得。前後の各宣言/受渡し/末端呼出/呼出側の位置は上表と一致。PR修正の四ファイルずつでは、旧root fieldが記載されなくなった一件を取得し、実行時依存の消滅とは出していない。JSON/textとも二回の出力bytesが一致。

| 入力 | before inventory SHA256 | after inventory SHA256 |
| --- | --- | --- |
| growth | `dce1108d465237f8f9ff080042be2c48f030fb9f9ae0242debab84e6cbe9ffaa` | `ad058b4d530092cab116a99745799da7f50d006009bdc88c93fa9f8bc12181a0` |
| repair | `82c82c59d132faa519404b74ccd85219025f53dedae4333acbf188edb2ef60e1` | `6aaa78c96968b4ff78bc362cf32caf7e67cdbd07dc323dc14b70398ccfbf88f0` |

hashはrelative pathとsource bytesの長さ付き連結。ソースと生出力はignored内。呼出側ContentViewはattributes/条件付きmemberを含むため、その型自体のfield解析は対象外だが、記載上の子へのargument位置は保持する。既知の同名bindingは候補を除外する。実callee・生成initの証明にはしない。

自作sourceのgrowth・組立済み除去、利用/wrapper/shadow/factory/local nominal/custom init/conditional/duplicate/signature/末端未利用を含む16負例と、parse/symlink/非UTF-8/隠しファイルparse失敗の4対照を二回ずつ検証。通常三fixtureだけSwift 6 typecheckを確認し、外部sourceは一切ビルド/実行していない。旧constructor対照も維持。独立コードレビューでsetter/observer parameterとgeneric calleeのshadow取り違えを指摘され、明示/暗黙accessor・generic・captureの名前を除外し、再現対照を追加した。

**得た成果は経路の機械取得であり、未見のレビューで役に立った証拠ではない。** content slot案の実改修/挙動検証も未実施。この範囲の取得が成立した後に、未見の実変更で「中間action APIを増やす理由と別配置」を検討する助けになるか、一件だけ判断する。一般graph/型解決/本番統合へは進まない。
