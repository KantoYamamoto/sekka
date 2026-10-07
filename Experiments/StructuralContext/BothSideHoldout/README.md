# 両側call入口の別未読比較（#102）

この文書は旧方式の検証記録。runtime/runnerの再現は固定commit `5177d21c476728e7fd4f3bbadba53cce9c181cfc`を別ディレクトリへarchiveして行う。現行CLIの契約・実行は[実験の入口](../README.md)を参照。

**既知の必要先へ届いた後は、同じ例を再採点せず、方式と選択を固定して別の未読変更を独立比較する。** [Issue #102](https://github.com/KantoYamamoto/sekka/issues/102)。前段の実装/既読再現は[検証記録](../../../docs/validation/both-side-call-entry.md)。本番/M3は保留。

選択/評価器の固定後、3入力の1,891 entriesをGit tree/blob/size/SHAへ照合し、通常diffの全変更範囲も確認した。残る1入力は固定beforeがmerge-baseと一致せず不成立。機械出力は固定バイナリの4mode各二回で終了コード/stdout/stderrの全bytesが一致。全3pairsの独立A/Bと結果点検、最終Actions/実Bot/10成果物までPR #104で完了。stage1の資料は原planと異なり非対称だったため、純増効果は評価できない。候補数や既知copy先例への到達を有用性の成功にしない。

- `plan.md`: source/diff/機械出力を見る前の原選択条件。PR #103のActions待ちだった時点の凍結文書で、現在の進捗ではない。
- `selection.json`: metadata/filename/status/countだけの監査、採用/除外理由と前後ref。cutoffは2026-10-04末（UTC）。大きさや候補の有無による差し替えはしない。
- `checkpoint.json`: source/Sources tree、binary/compiler、出力modeと凍結hash。PR最終sourceとlocal検証binaryのSources treeは同一。入力素材の検証完了を意味しない。
- `execution.json` / `review-material.json`: 4mode各二回の全bytes一致と、両armへ渡したstage1資料のhash。独立比較の結論を意味しない。
- `inputs.json` / `input-validation.json`: 取得3件の全path/mode/byte/blob/SHAと、選択4件の成立/不成立。raw本文を含めない。

## 入力を比較へ渡す境界

**固定refがPRの比較元と一致しない場合は、入力不成立として残し、同じ比較中にrefや対象PRを差し替えない。** Collections #745の固定before `afb6141` は分岐元 `98ef3c9` とは異なった（ahead2/behind5）。そのsource/diff/queryは取得せず、候補0とも未到達とも数えない。別refへ直せばPR素材として読めるが、source閲覧前の選択監査と違う入力になるため今回の比較へ混ぜない。次の独立選択では分岐元の照合も選択時に済ませる。

**素材のpath表記だけが照合器に未対応の場合は、既知metadataと厳密対応させて検証器を直し、評価器や入力内容は変えない。** #747には空白を含む未引用GitHub diff pathが63件あった。元照合器は空白で分割して拒否したため、[verify_diff.py](verify_diff.py)でheaderを凍結metadataの一つのpath対に対応させ、hunk前のfile markerの末尾tabだけを扱う。hunk内容・status/mode・全gap/tailの検証は既存照合器へ渡す。単純な空白分割や任意のtab削除ではpathや削除sourceの内容を変えてしまう。[対照](verify_diff_controls.py)と既存対照をCIで実行する。これは素材の検証能力の修正であり、Sekkaの検索条件や結果の補正ではない。

[比較結果と解釈制限](../../../docs/validation/both-side-call-holdout.md)へ、機械寄与0・新経路の1件の実使用・露出訂正・原手順との相違を統合した。GRDB #1885の配置の問いは通常sourceからで、必要性についてA/Bは異なる。次は[診断 #105](https://github.com/KantoYamamoto/sekka/issues/105)で、変更された既存窓口を不変target条件だけで除外する範囲を見直す。新たな未読比較は両stage1へ同じ通常diffを渡す契約を事前固定する。時間やトークン数だけで効率を断定しない。

raw source/diff/出力/レビューはignored `.build/both-side-comparison/`、公開は位置/count/hashと自分のcode。外部OSSはGET/readのみ、対象checkout/build/test/scriptや先方への投稿は禁止。人間判断待ちなし。
