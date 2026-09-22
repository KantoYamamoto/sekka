# 固定実PRへの到達範囲

M2 #77の小標本。出力に合わせて選び直さず、選定条件と候補順を`selection.json`に保存した。Swift CollectionsのSources、GRDBのGRDB配下でSwiftが変わったPRを、各repoで作成日降順・2026-09-21までにmerge済み・最大40件から最初の2件選んだ。コメントだけの変更も除外しない。

`inputs.json`はPR/前後commitと取得したファイルのGit blob ID・SHA-256・サイズ。前版はPRのbase/headのmerge-baseを使う。productionの指定配下のSwift全件に加え、通常読解用の変更ファイルとlicenseを含む。機械検索はproduction prefix内に限り、出力のpathはそのprefixからの相対位置。生成物・SDK・範囲外の宣言は対象に含まない。

## 再現

固定評価器は`b23a44e707ca4baf76bb9198b3fb81e165780e33`。初回はSwift 6.3.3 / SwiftSyntax 603.0.1、バイナリSHA-256 `c1ed75d7616785eb331190900239a9ff22c31e465741124b5a9213ef3a94f30a`の保存評価器で実行した。下記は固定ソースを再構築する手順であり、保存評価器と同一バイトの実行を保証しない。compiler versionとバイナリSHAを別途保存し、異なるtoolchainでの結果は初回結果と区別する。初回と同じ条件での再構築にはSwift 6.3.3を選択する必要がある。評価対象OSS自体はビルド・実行しない。

```sh
set -e
mkdir -p .build/reach-evaluator
git archive --output=.build/reach-evaluator/source.tar b23a44e707ca4baf76bb9198b3fb81e165780e33 Experiments/StructuralContext
tar -xf .build/reach-evaluator/source.tar -C .build/reach-evaluator
swift --version > .build/reach-evaluator/toolchain.txt
swift build --package-path .build/reach-evaluator/Experiments/StructuralContext --scratch-path .build/reach-evaluator/build
shasum -a 256 .build/reach-evaluator/build/debug/context-probe > .build/reach-evaluator/binary-sha256.txt
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/Reach/inputs.json --output .build/reach-input
python3 Experiments/StructuralContext/Reach/run.py --binary .build/reach-evaluator/build/debug/context-probe --input .build/reach-input --output .build/reach-result
```

入力/出力先は新規ディレクトリを使う。`fetch.py`は固定blobをGETして照合するため、3,008ファイルエントリの取得には時間とAPI要求を使う。初回評価では固定commitのarchiveをGETし、選択ファイルのGit blob IDをGit treeと照合して取得した。元のライセンスは保持し、生ソース・archive・diff・レビューはGitへ入れない。外部OSSへの投稿や変更は行わない。

`run.py`は全入力の一覧/ハッシュを先に照合し、各例を2回実行して結果の安定性を確認する。解析失敗は失敗として保存し、0候補に含めない。`results.json`は解析結果であり、有用性の採点ではない。初回の通常読解は機械出力を見る前に独立担当が行う。繰り返し実行を未見評価とは呼ばない。
