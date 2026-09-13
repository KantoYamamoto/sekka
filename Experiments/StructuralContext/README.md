# 変更と既存実装の接点を確かめる実験

本番の機能ではない。[判断0036](../../docs/decisions/0036-change-context-retrieval.md)に従い、変更宣言を入口に既存の構築や共通入口の使用位置を探す。ツールはSwift構文を決定論的に読み、LLMや対象アプリのビルドを使わない。

```sh
set -e
swift test --package-path Experiments/StructuralContext --scratch-path .build/structural-context
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-checks.json
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/holdout-inputs.json --output .build/context-input
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-oss.json --oss-input .build/context-input
.build/structural-context/debug/context-probe .build/context-input/wordpress-ios-25624/before .build/context-input/wordpress-ios-25624/after --text
```

Swift 6以降とSwiftSyntax 603.0.1が必要。`context-probe BEFORE AFTER`はJSON、末尾の`--text`は同じ材料を罫線で表示する。WordPress/Nukeは[#62で既読になった入力](../../docs/validation/context-holdout.md)であり、新方式の未見の有用性検証には数えない。

## 表示する事実と限界

- 関数と型/ファイル直下のproperty bindingの表記変更を入口にする。ファイル・字句上の所有者・署名が一意な前後だけ照合し、同じキーが複数ある場合は曖昧として残す。意味上の宣言同一性を解決したものではない。
- 変更後の宣言と、2つ以上の呼び出し表記を共有する変更前の宣言を最大3件示す。receiverの表記と引数ラベルを含み、receiverを省略した`.success(...)`等はこの検索から除く。基準は変更後の宣言で、相手側のbefore/afterごとに共通表記を計算する。移動後に表記が消えた場合も明示する。同じ役割・同じ対象への呼び出しとは断定しない。
- 関数名と引数ラベルが同じ使用位置を前後で示す。同じselectorは1グループに集約。宣言候補は最大3件、使用位置は各side最大8件で、残り件数も残す。宣言候補が1件でも実際の呼び出し先とは未解決。
- ローカル関数の本体は別に索引化する。overload、局所shadow、既定引数、末尾closureのラベル省略、外部宣言などで一致/不一致の意味が変わる。型推論や実行順序は扱わない。
- 条件コンパイルの条件は評価せず各branchを読む。条件式そのものは呼び出しに数えない。macro展開、init/subscript等の索引化、variable修飾子や含有型の変更を入口にする処理は未対応。

`contexts`は共有表記/selectorグループへの参照、`selectorGroups`は重複しない使用位置、`withoutContext`は材料を得られなかった宣言の先頭8件と省略数。0件や材料なしは構造の適切さを示さない。前後ファイル数・対応が曖昧な宣言・対象範囲も残す。汎用APIやテストの類似によるノイズは残り、設計の警告として常設する段階にはない。

## 入力の境界

入力配下のドット名は除外する。入力ルート/祖先の名前やFinder非表示属性は除外条件にしない。ルート自身/配下のsymlink、読取り失敗・構文エラーは終了2で部分出力せず停止。祖先symlinkは正規化して許容する。本番のGit入力/ignoreとは別の実験用ディレクトリ入力。

OSS再現には`gh`の読み取り認証とネットワークが必要。`fetch.py`は固定blobをGETで取得し、Git blob ID・SHA-256・サイズを照合する。`--manifest`省略時は旧実験の`inputs.json`。新方式の材料は上記の`holdout-inputs.json`を明示する。出力先は新規ディレクトリに限り、途中失敗した入力を解析しない。対象は選択したファイルであって全リポジトリではない。

第三者ソースはGitへ保存せず、元のライセンスを維持する。対象アプリのコード/ビルド/スクリプトを実行せず、対象OSSへのコメント・Issue・PR・その他の変更も一切行わない。

## 以前のclass配置抽出を再現する

[結果](../../docs/validation/class-context-experiment.md)と[#62での評価](../../docs/validation/context-holdout.md)を残し、常設実装を上記方式へ置換した。以前のCLIは固定commitから再現する。

```sh
set -e
mkdir -p .build/archived-class-context
git archive --output=.build/archived-class-context/input.tar f76bfd32911fa8606f1c06d85a414a0aee8d1b7e Experiments/StructuralContext
tar -xf .build/archived-class-context/input.tar -C .build/archived-class-context
swift test --package-path .build/archived-class-context/Experiments/StructuralContext --scratch-path .build/archived-class-context/build
python3 .build/archived-class-context/Experiments/StructuralContext/verify.py --binary .build/archived-class-context/build/debug/context-probe --output .build/archived-class-context/result.json
```
