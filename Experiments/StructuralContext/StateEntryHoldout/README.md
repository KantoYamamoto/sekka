# #113: 状態・操作入口の限定比較

**新しい入口は、別入力で構造の比較に使われてから次の投資を決める。** [plan](plan.md)と[freeze](freeze.json)はsource/diffを見る前、[selection](selection.json)は取得前に固定した。結果は[検証記録](../../../docs/validation/state-entry-holdout.md)、進行は[Issue #113](https://github.com/KantoYamamoto/sekka/issues/113)。既読での候補到達、未見の案内、配置再考への寄与は別に扱う。

Ice PR528とKeyboardShortcuts PR216の2件をmetadata順だけで選択した。`inputs.json`は固定対のtree/blob/mode/size/SHA、`input-validation.json`は全通常diffのhunk/gap/tail、`execution.json`は固定binaryのJSON/text各二回一致。時間はdebug process時間でありレビュー時間ではない。Bに渡した追加資料はtextだけ。A/Bの共通Swift diffは同一bytesで、`review-material-*-both.json`に包装hashを残す。

公開するのは自作code、位置・数・hash・所見だけ。外部source/diff/機械出力/生レビューはignored packet。先方への操作、対象checkout/build/test/scriptは行わない。両stage1 checkpointの保存後に同じcaseのsourceを開放した。担当は同じまま継続し、他担当/他case/開発経緯を読まない指示で分離する。OS隔離や盲検効果量の測定ではない。

## 再現と点検

取得/実行/包装scriptは自身のfolderへ書き込むため、**使用する際は新しいignored作業場所へコピーする。公開folderで取得しない。** `select_inputs.py`はmutableなmetadata取得用であり、凍結した比較の入力を選び直すためには使わない。取得は既存の`DirectRelationsHoldout/materialize_inputs.py`をignored rootへコピーして使用した。

`run.py`は同じrootの`freeze.json`、`state-probe`、`inputs.json`、`input-validation.json`、`packet/`を使用する。repo rootから実行し、出力`replay/`の既存資料は上書きしない。`prepare_reviews.py`も同じrootへコピーしてcase別に使用した。公開promptは今回の指示そのもので、rawレビューではない。

```sh
python3 Experiments/StructuralContext/StateEntryHoldout/audit_receipts.py \
  --root .build/state-entry-holdout \
  --output .build/state-entry-holdout/receipt-audit-new.json
```

private packet、binary、全レビューが必要。点検は保存資料の整合確認で、対象の実行・評価器の再実行を行わない。二回一致は実行時receiptとの結合であり、署名された証明ではない。構造の比較機会がないことと、機会があって案内が使われないことを分け、入力差替えやこの2件に合わせたrule調整はしない。
