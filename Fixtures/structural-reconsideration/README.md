# 構造の再検討に必要な材料

`cases.json`は#52の7つの合成入力。`reviewExpectation`は検証側の期待する確認事項であり、設計の正解やSekkaへの入力ルールではない。独立担当へはこの期待を渡さない。

`cards.json`は作者がソースから手作業で選んだ出力案。固定した隣接呼び出しの表記・位置・件数とLogger/ConsentSessionのソースを並べた。一般的なパターン検出器の出力ではない。未対応の表記、型解決、実行頻度、同意・寿命を推測しない。

現行Sekkaで構文解析と出力を再実行するには、リポジトリルートで次を実行する。

```sh
python3 Scripts/review_probes.py --cases Fixtures/structural-reconsideration/cases.json --output .build/structural-probes.json
```

この実行は期待終了コードと観測を記録するだけで、カードの自動生成やレビュー成功の判定はしない。[計画](../../docs/validation/structural-reconsideration-plan.md)と[成功条件](../../docs/decisions/0031-structural-success.md)を参照する。
