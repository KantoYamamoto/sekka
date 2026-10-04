# 戻り値名/call経路の固定比較（#95）

PR #94の実験評価器を固定し、既知8PRを除いた別4PRで通常diff/検索と案内併用を比較する。repo自体の未見とはしない。0候補/無関係候補/解析失敗を差し替えず、新経路と既存経路の寄与を分ける。

選択は`selection.json`、実行前の[計画](plan.md)、全3,006入力は`inputs.json`、source/binary/toolchain/素材hashは`checkpoint.json`。二回実行は`execution.json`、初期資料/共通課題は`review-checkpoints.json`と`review-prompt-*.txt`、段階開放と生レビューhashは`review-receipts.json`、位置別の経路とB実使用分類は`candidate-audit.json`。[結果と次の判断](../../../docs/validation/result-relations-holdout.md)。第三者source/body/diffと生レビューはGit管理外。公開checkpointのcommandは移植用placeholderで、元の絶対commandを持つignored checkpointのSHAを別に記録する。Hashから生レビュー/当時のPR本文を復元できるとはしない。

独立計画点検で検索の完全性、diffと固定sourceの一致、新旧経路重複の帰属を修正。保存検索はcomplete/40件で選択不変。`verify_diff.py`はpath/status/mode、全text hunkと未記載gap/tailを前後bytesへ照合し、空/部分diffを拒否。`diff-source-checks.json`は65ファイル/381 hunkのmetadataだけで、全件text一致。独立点検後の7有効/11不正の合成対照も通過。

```sh
python3 Experiments/StructuralContext/ResultHoldout/verify_diff_controls.py
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/ResultHoldout/inputs.json --output .build/result-holdout-input
python3 Experiments/StructuralContext/Reach/run.py --manifest Experiments/StructuralContext/ResultHoldout/inputs.json --binary BINARY --input .build/result-holdout-input --output .build/result-holdout-output
```

評価器は`a2172a0d4cc5c3f309cdefabc68b82d8ff3b6a9c`の自分のpackageをarchive/buildする。Swift6.4/SwiftSyntax604.0.0、初回保存binaryのSHA256はcheckpointへ記録。再ビルドが同じbyteになる保証はなく、toolchain/OS/binaryを別に保存する。対象OSSのcheckout/build/test/scriptは実行しない。

fetchは固定blobのGETで全source/metadataを照合する。ordinary.diffは`GET repos/REPOSITORY/compare/BEFORE...AFTER` / `Accept: application/vnd.github.diff`で取得し、manifestのdiffSHA256と照合して各caseの`ordinary.diff`へ保存する。この後に`verify_diff.py --manifest .../inputs.json --input .build/result-holdout-input --output .build/result-holdout-material.json`で再検証する。binary表示はmetadataだけを検証し、text本文の一致とはしない。C escapeされたpathは未対応として停止する。対象への投稿・変更なし。

レビューはcase別の履歴なしA/B、stage1 checkpoint確認後に同じdiff/sourceを開放。必要先・具体的な反復負担・別配置/成立条件・現配置の支持理由を区別し、案内だけで構造目的を達成扱いしない。全4件の比較と独立結果点検は完了、未解消の修正要求なし。`independent-review.json`は6,260検査と限定のreceiptで、body/生レビューは含めない。新経路は1文脈先、必須確認先への増分利益や成立した構造の問いは未支持。本番統合/M3は保留。次は#96の診断。
