# 0005: JSONは差分中心を標準にする

**方針：diffをJSONで渡す場合は変化した要素を標準にし、完全な前後情報も選べるようにする。**

- 記録日：2026-09-06
- 状態：採用
- 経緯：試用フィードバックと改善実装 `f7ccc3b` から遡及記録

## 目的・状況

PR #81の旧JSONは56,592文字で、通常のSwift diffの約2.1倍だった。AIに渡す入力を減らしつつ、解析範囲や省略理由を失わないようにしたい。

## What — 選ぶこと

diff JSONはcompactを標準とし、`removed` / `added` と必要な引数差分を出す。`--json-detail full` では `before` / `after` の全リストを残す。両形式のcoverage・notices・limitationsは同一にする。

## Why — 選ぶ理由

変わっていない多数のメンバーを毎回送る必要がなくなる。詳細を必要とするスクリプトの用途も残せる。情報構造が変わるためschemaを2に上げ、利用側が変更を識別できるようにする。

## Why not — 別案を採らない理由

インデントだけを詰めても、冗長な内容を読む負担は残る。前後情報の完全廃止は既存用途を失わせる。省略理由まで削ると小さくなるが、解析した範囲を誤読させるため採らない。

## How — 実現方法

[CompactReport.swift](../../Sources/PatchworkCore/CompactReport.swift)で変更要素だけに変換する。[CLI](../../Sources/patchwork/main.swift)でdetailを選択し、旧フィールドを読む利用側にはfull指定またはschema移行を案内する。scanはsnapshot出力を維持する。

## 制約・見直す条件

compactから完全な前後状態は復元しない。旧 `findings[].after` 等を読むスクリプトには対応が必要。実データでまだ長すぎる場合は構造を再検討するが、schema変更と情報の省略範囲を記録する。

## 根拠・確認

[検証結果](../review-output-v2.md)では29,817文字へ47.3%減。文字数でありtoken数・費用の削減率ではない。[テスト](../../Tests/PatchworkCoreTests/CoverageTests.swift)でcompact/fullの比較範囲情報が一致することを確認した。
