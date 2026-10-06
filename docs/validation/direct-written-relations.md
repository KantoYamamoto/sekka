# #107: 関係を直接出す実験CLI

**変更された既存窓口を読む必要がある場合は、未変更target検索へ継ぎ足さず、同形変更・所属領域・利用表記を直接示す。** 目的と別案は[0049](../decisions/0049-direct-written-relations.md)、実行契約は[実験README](../../Experiments/StructuralContext/README.md)。本番CLI/M3は保留、未読利益は未確立。

## 現在の根拠

旧索引/4検索経路/テストを現行packageから撤去し、#105で点検した領域readerを再利用。Swift内部で関係を作り、JSON/罫線textへ必要な形と全位置を直接出す。parser/read error境界を維持する。旧runtimeの再現は固定commit `5177d21c476728e7fd4f3bbadba53cce9c181cfc`へ残し、常設CIは現行契約の対照へ整理。

初稿は13 Swiftテスト/31 CLI対照（BOMの識別/物理offsetを含む）を通過。条件/header変更、曖昧owner/switch、追加/削除、共有済み規則、異なる引数/closureラベル、Unicode bytes、コメント/空白、形詳細省略と全位置、parse/read失敗と正常0を分ける。CLIはJSON/text/allの終了コード/stdout/stderr全bytesを二回照合する。独立code/factレビューは進行中。

同じ既読3入力の初回再生は全1,891 entriesのinventory/size/blob/SHAを照合し、JSON/textを各二回実行。#105との関係・owner・users・unknown全位置と差異flagが一致。新しい共通call表記の位置とsame-basename宣言候補は実calleeへ解決せず反対材料へ進む入口として出す。

| 既読入力 | 関係 / before+after利用表記 / unknown group | JSON / text bytes（初稿） |
| --- | --- | --- |
| swift-collections #747 | 0 / 0 / 23 | 8,120 / 4,102 |
| GRDB #1885 | 1 / 2 / 4 | 14,322 / 5,405 |
| GRDB #1884 | 0 / 0 / 4 | 3,564 / 2,141 |

これらは同じ素材の再検証で、未読PRの利益ではない。59MB等の診断dumpを常設要約pipelineへ持ち込まず直接出力できたことと、配置を考え直す判断へ寄与することは分ける。

## 再現と未完了

入力manifestは[#102の固定素材](../../Experiments/StructuralContext/BothSideHoldout/inputs.json)。取得済みprivate packetを使い、対象checkout/build/test/script/外部投稿は行わない。runnerは全packetと対照binary SHAを検証し、出力先を上書きしない。

```sh
python3 Experiments/StructuralContext/DirectRelations/replay.py \
  --packet .build/both-side-comparison/packet \
  --inputs Experiments/StructuralContext/BothSideHoldout/inputs.json \
  --binary .build/direct-relations/relations-probe \
  --checks .build/direct-relations/checks.json \
  --output .build/direct-relations/replay-new
```

第三者source/diff/形の生出力はignored。公開記録は位置/count/hashとown code。現在は独立レビュー・最終評価器固定/再生・自己利用・Actions/実Bot/成果物が未完了。ローカルの再buildでは生成test bundleのFinder metadataによる署名エラーが出たため、own `/tmp` scratch/native buildで13テストを通過。解析対象の問題と混同しない。未完了を正常成功としない。

次は固定評価器を使った未読比較。両stage1に同じPR説明/通常diffを先渡しし、commonsource前のcheckpointを保存する。既読到達/圧縮率は合格条件にしない。配置再考へ寄与せず別の決定論的根拠もなくなれば、用途限定/撤退の判断を人間へ通知する。
