# Dependency relay: 一課題の試作

中間APIが依存/callbackを渡すために増えた理由と、組み立てる場所を見直す比較案を示す独立実験。本番Sekkaへは未統合。実sourceに合わせた取得単位は[0053](../../docs/decisions/0053-stored-callback-relay.md)、先のconstructor試作は[0052](../../docs/decisions/0052-config-free-first-problem.md)。

```sh
swift build --package-path Experiments/DependencyRelay --scratch-path .build/dependency-relay
RELAY_BIN=$(swift build --package-path Experiments/DependencyRelay --scratch-path .build/dependency-relay --show-bin-path)
python3 Experiments/DependencyRelay/check_callback.py "$RELAY_BIN/callback-probe"
"$RELAY_BIN/callback-probe" Experiments/DependencyRelay/CallbackFixtures/before Experiments/DependencyRelay/CallbackFixtures/after --text
```

## callback-probe（今回の取得単位）

前後のsourceディレクトリを受け取り、同じ開始/末端field・型表記の経路が一段から二段以上へ増えた場合、各保持宣言・受渡し・末端呼出・呼出側の位置を示す。呼出側で末端を組み立てcontent slotを渡す比較案と、items契約/所有/identity/更新/snapshotの条件はJSONにも含む。中間型全体の責務や設計の良否は判定しない。

供給inventory内で一意なplain struct、明示const function field（記載戻り値Void）、直接named argument受渡し、当該fieldの一回だけの呼出表記に限定する。shadow・同名・custom init/generic/attributes/extension/条件付きownerは対象外。呼出callee/生成init/実際の型同一性は未解決。root fieldの削除は実行時依存の消滅と区別する。

`--text`なしではJSON。隠しSwiftファイルも含め、1〜128 Swiftファイル・各4MB/合計20MB以下のUTF-8を読む。symlink/read/parse失敗はstderrとexit 2、部分JSONは返さない。sourceはビルド/実行しない。同じrelative path/bytesから同じhashと出力。0件は構造の承認ではなく、範囲外や無関係な経路も省略される。

bilibili_tvの固定履歴で1→2の増加と後のroot field削除を取得した。[検証](../../docs/validation/stored-callback-relay.md)。修正を知った事後診断なので、未見の利用価値や本番採用の合格ではない。

## relay-probe（先のconstructor取得可能性）

```sh
python3 Experiments/DependencyRelay/check.py "$RELAY_BIN/relay-probe"
"$RELAY_BIN/relay-probe" Experiments/DependencyRelay/Fixtures/before.swift Experiments/DependencyRelay/Fixtures/after.swift --text
```

一ファイル内の一意な明示型・一つの明示init・直接代入/構築、全段で新引数が加わる場合に限定。4MB以下のUTF-8通常ファイル二つを比較する。自作例ではEventSinkが二つの中間constructorで子へ渡され、Checkoutで保持/参照される。別配置は子を組み立てた後に親へ注入すること。生成時期/所有/アクセス/構築を隠すAPI契約は別途確認する。

自作対照と独立レビュー修正まで完了。実SwiftLog #238は条件付き宣言で未解析、今回のSwiftUI実例は明示initがなく未解析。この方式の未対応を増やすことは次の目標にしない。両試作の自作成果物だけをActionsに保存する。
