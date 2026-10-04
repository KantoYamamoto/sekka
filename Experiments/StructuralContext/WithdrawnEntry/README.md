# 減った利用表記と残る窓口の診断（#96）

afterのcallから必要な共通先例へ届かない場合は、beforeで使っていた窓口が残るかを調べる。[実行前計画](plan.md)と[必要位置58件](needs.json)を固定し、#95の同じ4PRで原因を診断する。今回の集合は既読で、未見の有用性・網羅的正解集合ではない。本番/実験libraryの検索は変更しない。

既存[Diagnostics](../Diagnostics/README.md)を再利用する。全ASTのcall dumpは形式/本文境界の確認用、利用数は`SourceInventory.functions[].writtenCalls`だけ。同形selectorの数が減り、両側一意の宣言・字句祖先headerがtoken同一かを照合する。読み取り位置の交差は契約の解析や実callee解決を意味しない。callerのキー対応なしを削除/rename/意味上の移行と断定しない。

```sh
python3 Experiments/StructuralContext/Diagnostics/verify.py --scratch /tmp/sekka-withdrawn-index --output .build/withdrawn-replay/checks.json
python3 Experiments/StructuralContext/WithdrawnEntry/verify.py --binary .build/withdrawn-replay/inventory-probe --output .build/withdrawn-replay/controls.json
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/ResultHoldout/inputs.json --output .build/withdrawn-input
python3 Experiments/StructuralContext/WithdrawnEntry/run.py --binary .build/withdrawn-replay/inventory-probe --input .build/withdrawn-input --output .build/withdrawn-index
python3 Experiments/StructuralContext/WithdrawnEntry/audit.py --binary .build/withdrawn-replay/inventory-probe --index .build/withdrawn-index --output .build/withdrawn-audit.json
```

readerは自分のtracked sourceのarchiveにだけ合成する。現在HEADでの再実行と当時の再現は区別し、当時は`execution-checkpoint.json`のsourceHeadを`Diagnostics/verify.py --source-ref`へ指定する。ビルドが同じbinary bytesになる保証はない。`run.py`は全3,006 entryの一覧/size/SHA/Git blobを照合し、4caseのexit/stdout/stderrを各二回比較する。入力は固定blobのGETだけ、対象checkout/build/test/scriptや外部投稿なし。

`checkpoint.json`は元の条件/必要位置/旧診断binaryの凍結記録。欠落directoryでは旧Foundation stderrにメモリアドレスが混じり不一致だったため、**診断のcatchだけ**をdomain/codeへ修正し、`execution-checkpoint.json`で修正後binary/当初22対照を別に固定した。そのcontrolsSHA256はignored `original-22-controls.json`の当時receiptを指す。後の恒久対照拡充はexecution.jsonへ分ける。元の失敗を消したりstderrを後処理して一致扱いしない。実験runtimeの同じ失敗表示は[#98](https://github.com/KantoYamamoto/sekka/issues/98)で別修正。本番scanの欠落directory対照は安定していた。

生dump/source/reviewsはignored。公開する`results.json`は全42groupの件数/form/status/occurrence hashと、適格4候補の全利用位置・条件位置/hash、宣言不変/対応状態、必要位置との交差を持つ。不適格38groupの全利用位置はreceiptでboundしたprivate indexへ残し、再掲しない。signature/body/receiver/条件本文は公開しない。`provenance-corrections.json`は必要位置/用途を変えず6件のreview行参照だけを訂正した記録。集計CLIは完了receiptと全case/manifest/binary/runner/実出力hashを照合し、25構文/失敗対照と12receipt対照（計37）を実行する。receiptは保存結果の整合確認で、実行の署名証明ではない。[結果と限界](../../../docs/validation/withdrawn-entry-diagnostic.md)。
