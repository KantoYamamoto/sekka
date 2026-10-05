# 両側call入口の別未読比較（#102）

**既知の必要先へ届いた後は、同じ例を再採点せず、方式と選択を固定して別の未読変更を独立比較する。** [Issue #102](https://github.com/KantoYamamoto/sekka/issues/102)。前段の実装/既読再現は[検証記録](../../../docs/validation/both-side-call-entry.md)。本番/M3は保留。

現段階は選択/評価器の固定だけ。素材取得・全entries/diffの照合、機械出力、独立A/B、結果点検は未実施。候補数や既知copy先例への到達を有用性の成功にしない。

- `plan.md`: source/diff/機械出力を見る前の原選択条件。PR #103のActions待ちだった時点の凍結文書で、現在の進捗ではない。
- `selection.json`: metadata/filename/status/countだけの監査、採用/除外理由と前後ref。cutoffは2026-10-04末（UTC）。大きさや候補の有無による差し替えはしない。
- `checkpoint.json`: source/Sources tree、binary/compiler、出力modeと凍結hash。PR最終sourceとlocal検証binaryのSources treeは同一。入力素材の検証完了を意味しない。

次は全source/blob/SHA/通常Swift diffを同じ範囲で照合し、履歴なしA（通常diff+全source検索）とB（同じ素材+既定位置一覧/全根拠）を段階隔離で比較する。具体的な負担・別配置の成立条件・現配置の反対理由をsource位置へ戻す。案内の寄与、通常検索の発見、必須/文脈/無関係、正常0/入力失敗/中断を分ける。時間やトークン数だけで効率を断定しない。

raw source/diff/出力/レビューはignored `.build/both-side-comparison/`、公開は位置/count/hashと自分のcode。外部OSSはGET/readのみ、対象checkout/build/test/scriptや先方への投稿は禁止。人間判断待ちなし。
