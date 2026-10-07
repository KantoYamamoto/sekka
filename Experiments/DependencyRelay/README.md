# Dependency relay: 一課題の試作

新しい依存のために中間constructorのAPIまで増えたとき、なぜ変更が連鎖したかと、子を呼出側で組み立てる別配置を短く示す。目的と採用理由・実変更の取得限界は[0052](../../docs/decisions/0052-config-free-first-problem.md)。本番Sekkaへは未統合。

```sh
swift build --package-path Experiments/DependencyRelay --scratch-path .build/dependency-relay
RELAY_BIN=$(swift build --package-path Experiments/DependencyRelay --scratch-path .build/dependency-relay --show-bin-path)
python3 Experiments/DependencyRelay/check.py "$RELAY_BIN/relay-probe"
"$RELAY_BIN/relay-probe" Experiments/DependencyRelay/Fixtures/before.swift Experiments/DependencyRelay/Fixtures/after.swift --text
```

`--text`なしではJSON。ソースを構文解析するだけで、対象をビルド/実行しない。UTF-8・4MB以下の通常ファイル二つを受け取り、parse/read失敗はstderrとexit 2、部分JSONを返さない。同じ入力path/bytesから同じ出力を返す。

自作例の実出力は、`EventSink`が`CheckoutScreen.init(repository:events:)`と`CheckoutModel.init(repository:events:)`で子の構築へ一回ずつ渡され、`Checkout`で保持/参照される記載を示す。比較案は`CheckoutModel(checkout:)` → `CheckoutScreen(model:)`へ組み立てを変更し、末端の将来の依存追加を中間APIから切り離すこと。生成時期・所有・アクセス・構築を隠すAPI契約は別途確認する。

一ファイル内の一意な明示型・一つの明示init・直接代入/構築に限定する。全段で新引数が加わる場合のみ。記載参照は実callee・副作用・責務の証明ではない。0候補や未解析は構造の承認を意味しない。暗黙initや複数ファイルの解析を製品の制約として採用したわけではない。

対照は通常の局所追加、組立済み、中間での利用/変換/closure、overload、条件コンパイル、shadow等とparse失敗。独立レビューで同名factoryと末端の引数shadowの誤認を修正した。自作の合格と実用性の合格は別。SwiftLog #238は前後ファイル全体が未解析だったため、本番へ進める証拠にはなっていない。
