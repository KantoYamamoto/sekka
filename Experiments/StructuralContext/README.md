# 変更から未変更の実装候補へ辿る実験

本番CLIへ採用する前の試作。[判断0038](../../docs/decisions/0038-outside-diff-context.md)に従い、通常diffを読むときに、変更していない既存実装も確認する入口を作る。Swift構文を決定論的に読み、LLMや対象アプリのビルドを使わない。

```sh
set -e
swift test --package-path Experiments/StructuralContext --scratch-path .build/structural-context
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-checks.json --text-output .build/context-checks.text
.build/structural-context/debug/context-probe BEFORE AFTER --text
```

Swift 6以降とSwiftSyntax 603.0.1が必要。`BEFORE`/`AFTER`は比較するSwiftソースを含むディレクトリ。末尾の`--text`を省くとJSON。`verify.py`は既存7対照と入力の境界を検証する。**合成例の成功は実PRで役立つことの証明ではない。**

## 何を案内するか

例えば、以前から`logger.record(event)`を呼んでいた関数に、直後の`analytics.record(event)`が加わったとする。`logger: Logger`という明示型、入力内の`Logger.record(_:)`候補、その宣言が前後で未変更という経路を位置付きで示す。3関数から同じ候補へ届けば、候補1件に3つの入口をまとめる。

出力は「この既存実装も確認できる」という材料。Loggerという名前から役割を推論せず、実際の呼び出し先や同じ責務、統合すべきという結論を確定しない。既存実装を読んで配置を再検討する価値は、別途評価する。

- 対象は一意に対応したmember関数の本体直下。旧版に同じトークン列の文がなく、直前に前後それぞれ1回だけ現れるmember callがあり、単純な識別子引数の表記を共有する場合に検索する。既存callの引数変更もこの条件を満たし得るため、挿入とは断定しない。隣接や同じ引数表記は関連性・同じ値の証明ではない。
- `SourceInventory`でreceiver propertyの明示型から名前/引数ラベルが一致する関数候補へ辿る。caller/targetの型ヘッダー、property、候補宣言の前後一致を確認する。行が移動しても新旧位置を保持する。
- 新規/削除/改名/曖昧な関数、nested block、try/await、複雑な引数式は初回範囲外。型推論、overload解決、extension、継承/protocol、macro展開は行わない。属性も未展開の宣言を作り得るものとして保守的に扱うため、通常の属性が検索を止める場合がある。[索引の詳細](../../docs/validation/source-inventory.md)。
- 未変更の関数から呼び出し元へ逆に辿る検索や、未変更の場所にも同じ組合せがあるかの検索は行わない。差分の意味・保存失敗・数式の正しさも扱わない。

## JSONとtext

`contexts`は未変更の関数候補ごとに、前後位置、`fileUnchanged`、変更からの`entries`を持つ。各entryにcaller、既存call、新規または変更call（`newOrChangedCall`）、receiverの型注釈の位置、型と共有引数の表記を持つ。textは同じ候補を罫線でまとめる。最大8候補・各8入口で、省略数は両形式で共有する。

`changedFunctions`は索引で一意に対応した変更関数数。`unpairedBefore/After`は対応外の索引内関数数。`skipped`は候補文を退けた理由、または対象callを持たない変更関数の理由の件数であり、ファイル数・解析網羅率ではない。そもそも索引にないトップレベル関数/init等もある。0件を設計の妥当性と解釈しない。

宣言のトークン未変更とファイル全体の未変更は区別する。hunkを比較していないので、その宣言がdiffのcontext行にも出ていないとは主張しない。JSONの`limitations`に検索契約を残す。

## 入力と再現の境界

入力配下のドット名は除外する。入力ルート/祖先の名前やFinder非表示属性は除外条件にしない。ルート自身/配下のsymlink、読取り失敗・構文エラーは終了2で部分出力せず停止。祖先symlinkは正規化して許容する。本番のGit入力/ignoreとは別の実験用ディレクトリ入力。

既読のOSS2件を再現する場合は以下。今回の方式の未見評価ではない。

```sh
set -e
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/retrieval-inputs.json --output .build/context-input
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-oss.json --oss-input .build/context-input
```

`fetch.py`は`gh`の読み取り認証を使い、固定blobをGETで取得してGit blob ID・SHA-256・サイズを照合する。manifestを明示し、新規ディレクトリへ取得する。途中失敗した入力を解析しない。選択したファイルが範囲であり、全リポジトリではない。固定資料の非Swiftファイルは解析しない。

第三者ソースはGitへ保存せず、元のライセンスを維持する。対象アプリのコード/ビルド/スクリプトを実行せず、対象OSSへのコメント・Issue・PR・その他の変更も行わない。

## 以前の方式

実験CLIを置換し、旧方式は固定commitに残す。class配置は`f76bfd32911fa8606f1c06d85a414a0aee8d1b7e`、call接点は`c0eb0b3f783262d0c43c1f189c338174725d584b`、参照減少/残存は`2f089f37de5d925e514df74a5317fb5d4cad1d91`。下記のREFを置き換えて別ディレクトリへ取り出す。

```sh
set -e
mkdir -p .build/archived-context
git archive --output=.build/archived-context/input.tar REF Experiments/StructuralContext
tar -xf .build/archived-context/input.tar -C .build/archived-context
swift test --package-path .build/archived-context/Experiments/StructuralContext --scratch-path .build/archived-context/build
python3 .build/archived-context/Experiments/StructuralContext/verify.py --binary .build/archived-context/build/debug/context-probe --output .build/archived-context/result.json
```

以前の結果は[class配置](../../docs/validation/class-context-experiment.md)・[call接点](../../docs/validation/change-context-experiment.md)・[参照差](../../docs/validation/reference-delta.md)。現在の結果は[未変更候補への検索](../../docs/validation/unchanged-context.md)。
