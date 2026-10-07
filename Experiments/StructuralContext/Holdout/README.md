# 固定した案内の独立比較資料

この文書は旧方式の検証記録。runtime/runnerの再現は固定commit `5177d21c476728e7fd4f3bbadba53cce9c181cfc`を別ディレクトリへarchiveして行う。現行CLIの契約・実行は[実験の入口](../README.md)を参照。

M2 [#87](https://github.com/KantoYamamoto/sekka/issues/87)。評価方法/判定は[実行前の計画](plan.md)、入力はinputs.json、候補順と除外はselection.json、実行前の凍結情報はcheckpoint.json。第三者の生ソース・PR本文/diff・生レビューはGitへ置かない。checkpointのrawSelectionSHA256は本文を含む非公開の凍結選択、publicSelectionSHA256は本文を除いた公開selection.jsonを指す。stage資料/初回runnerのhashも受領記録であり、公開ファイルのhashとは別。再現用の共有runnerと初回出力は照合済み。PR本文はsource commitで固定されないため、同じ機械結果から当時のレビュー資料を復元できるとはしない。

同じ2repoの別PRを、機械出力閲覧前に作成日順で選んだ。既読#77の4件を除き、最大40の先頭からproduction Swift変更2件ずつ。コメントだけの変更も含み、候補が出ない場合も差し替えない。これはrepo自体の未見ではなく、別の未読PRを履歴なしの担当が比較する小標本。

評価器sourceはPR #86 head `2fa28101059f017f11467eb97c9be2ffdffa51d4`。保存したローカルbinaryはSwift 6.4 / SwiftSyntax604.0.0、SHA-256 `5376f29bdbfb15a24c150792c43b77da33d53704b65050c0a0adbbd2c2bb7626`。再ビルドは同じbyteの保証ではなく、OS/compiler/binary hashを別に保存する。

## 機械結果の再現

```sh
set -e
mkdir -p .build/holdout-evaluator
# 対象OSSではなく、固定したSekka試作をビルドする。
git archive --output=.build/holdout-evaluator/source.tar 2fa28101059f017f11467eb97c9be2ffdffa51d4 Experiments/StructuralContext
tar -xf .build/holdout-evaluator/source.tar -C .build/holdout-evaluator
swift --version > .build/holdout-evaluator/toolchain.txt
swift build --package-path .build/holdout-evaluator/Experiments/StructuralContext --scratch-path .build/holdout-evaluator/build
shasum -a 256 .build/holdout-evaluator/build/debug/context-probe > .build/holdout-evaluator/binary-sha256.txt
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/Holdout/inputs.json --output .build/holdout-input
python3 Experiments/StructuralContext/Reach/run.py --manifest Experiments/StructuralContext/Holdout/inputs.json --binary .build/holdout-evaluator/build/debug/context-probe --input .build/holdout-input --output .build/holdout-result
```

入力/出力は新規フォルダを使う。fetchは固定blobのGETで照合するため、3,026ファイルエントリの取得にはAPI要求/時間を使う。初回は固定commitのarchiveをGETし、選択regular fileだけを安全に読み、Git tree/blob・SHA-256・サイズ/全一覧を照合した。targetのcheckout/build/scripts/test/先方への投稿は行わない。licenseを保持する。

共有のReach/run.pyにmanifestを渡して再実行する。JSON/textをそれぞれ二回実行、exit status/stdout/stderrを全バイトで比較。読取り/解析失敗は正常0と分ける。最初の完了結果と共有runnerの再実行一致を別途確認する。機械資料の再現性とAIレビュー所見の再現性は同じではない。

## 比較結果の扱い

A/Bは各caseで新しい履歴なし担当。AはPR本文→普通のdiff、Bは同じ本文→機械案内を先に読み、checkpointを保存。両者の保存を確認してから同じdiff/before/after sourceを開放。相互結果や開発者の既知所見は渡さない。共有workspaceのallowed path制限を指示し、誤閲覧があれば逸脱として記録する。

必要箇所への到達と、具体的な継ぎ足しの負担/別配置/成立条件/現配置の支持根拠を分ける。探索の補助だけを構造目的の達成に昇格させない。時間/token/人間の負担減少や全PRへの一般性は結論しない。結果は[検証文書](../../../docs/validation/member-relations-holdout.md)へ統合した。review-checkpoints.jsonは段階資料/開放/レビューのhashの受領記録。生レビューはGitへ置かず、hashだけから内容を再生できるとはしない。
