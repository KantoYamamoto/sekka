# #109: 直接関係の未見比較

**未見比較では入力を見る前に選択と評価器を固定し、通常diffと機械案内の寄与を分ける。** [凍結plan](plan.md)は変更しない。現在の結論は[検証記録](../../../docs/validation/direct-relations-holdout.md)、進行は[Issue #109](https://github.com/KantoYamamoto/sekka/issues/109)。本番採用の証明ではない。

`selection.json` はmetadata/全変更filenameによる選択、`inputs.json` は固定merge-base/headのtree/blob/mode/size/SHA、`input-validation.json` は通常diff全hunk/gap/tailの照合。source/diff/機械出力の形/生レビューはignoredのprivate packetに残し、公開版はown code、位置・数・hash・所見だけにする。対象のcheckout/build/test/scriptや外部投稿はしない。

## 再現と証拠の区別

選択/取得scriptは自分の所在へ結果を書く。**実行する場合は先にignoredの新しい作業場所へコピーする。** 公開folder内で取得しない。今回のref・選択は凍結済みで、mutableなPRを再取得して同じ比較へ混ぜない。`selection_controls.py` は自分の合成metadataのみを使い、外部通信しない。

```sh
python3 Experiments/StructuralContext/DirectRelationsHoldout/selection_controls.py
python3 Experiments/StructuralContext/BothSideHoldout/verify_diff.py \
  --manifest Experiments/StructuralContext/DirectRelationsHoldout/inputs.json \
  --input .build/direct-relations-unseen/packet \
  --output .build/direct-relations-unseen/diff-audit-new.json
python3 Experiments/StructuralContext/DirectRelationsHoldout/audit_receipts.py \
  --root .build/direct-relations-unseen \
  --binary .build/direct-relations/relations-probe-text-state \
  --output .build/direct-relations-unseen/receipt-audit-new.json
```

private packetが無ければ後二つは実行できない。評価器のsource/toolchain/controlsは[#107](../DirectRelations/results.json)で固定。JSON/textの二回実行は[共通runner](../DirectRelations/replay.py)、`--all`は今回使った`run_all_modes.py`を同じprivate rootへコピーして行った。`prepare_reviews.py`も今回の包装scriptの保存で、両groupの通常Swift diffは同一bytes、Bだけ出力を追加する。固定済み資料を上書きしない。最初の包装scriptの版差は材料hashを照合して記録し、同じscript版だったことにはしない。

`execution.json` の `meaning` は共通runnerの歴史的な文字列（known-input replay）。実際の入力は今回新しく選んだ4件であり、このreceipt単独は未見有用性を示さない。`all-modes.json` はdebug binary/2並行jobsのprocess時間で、レビュー時間・release性能ではない。`receipt-audit.json` は保存資料との整合確認であり、署名された実行証明ではない。

一次レビューのcheckpointは共通source閲覧前に保存。stage2は両groupに同じpacketを許可した。GRDB #1879は中断による担当交代を残し、同一担当の継続比較や効果量として扱わない。結果は必要な差分外位置、単なる便利文脈、問いの四条件、普通のsource由来の材料、機械出力の実使用を分ける。0関係を問題なしと解釈しない。
