# 呼び出し並びの拡大: 実験

**これはSekkaの製品機能ではありません。** #54で、同じ隣接呼び出し表記の配置が増える事実と、変更していない既存位置を取り出す仮説を検証します。設計判断・重複した責務・解決済みの依存とは呼びません。

```sh
swift test --package-path Experiments/CallSequences --scratch-path .build/call-sequence-experiment
python3 Experiments/CallSequences/verify.py --binary .build/call-sequence-experiment/debug/call-sequence-probe --output .build/call-sequence-results.json
swift run --package-path Experiments/CallSequences --scratch-path .build/call-sequence-experiment call-sequence-probe BEFORE_DIR AFTER_DIR
```

Swift 6以降、SwiftSyntax 603.0.1。対象ソースは解析するだけで実行・ビルドしません。初回にこの実験とSwiftSyntaxをビルドします。ディレクトリ全体の`.swift`を読み、入力配下の名前が`.`で始まるパスを除外（入力ルートや祖先の名前・Finderの非表示属性は除外条件にしない）、入力ルート自身/配下のsymlinkと構文エラーは失敗にします（祖先のsymlinkは正規化して許容）。本番のGit比較・除外設定とは別の限定した入力です。

出力は`expansions`の各組にトークン表記とbefore/afterの位置。単位は関数宣言の配置数で、実行回数ではありません。既存同名関数の前後対応は行わず、各スナップショットの配置集合を数えます。同じ関数内の反復は最初の位置1件です。

完全一致だけなので、名前が変わると関連を拾えません。逆に同じ表記でもレシーバー型や意図は異なるため、同じ処理だとは断定できません。クロージャ・ローカル関数・条件コンパイル内、return/代入/try/await/trailing closureは対象外。普通の分岐内は読みますが条件を評価しません。出力なしは問題なしを意味しません。既存Loggerのような移動先の自動選定も行いません。

採用する場合は本番の入力・観測モデルへ統合してこの実験を撤去するか、見送って削除するかを判断します。第2の製品CLIとして保守する計画ではありません。[判断0032](../../docs/decisions/0032-call-sequence-experiment.md)を参照してください。
