# 構造についての問いを検証する入力

6件の合成入力。Logger、SwiftUI、モデル/enumを各2条件で比較する。`question`と`context`は解析前に固定した評価側の文脈であり、Sekkaが推定した情報ではない。`context`は評価器に渡されない。

```sh
python3 Scripts/review_probes.py --cases Fixtures/design-review/cases.json --output .build/design-review/results.json
```

既存のprobe実行器を再利用する。終了コード一致だけを成功条件にしており、設計の正解・有用性の合格を自動判定しない。各before/afterの辞書をディレクトリへ展開すれば通常の`sekka diff --before ... --after ...`でtext/full JSONも読める。

Loggerの2条件は意図的に同じコードと異なる方針を持つ。構文からチームの意図を捏造しないことを確認する対照例。SwiftUIの子View案や単純計算の追加も、絶対的な正解ではなく、一方向の統合・分割を促さないための対照とする。
