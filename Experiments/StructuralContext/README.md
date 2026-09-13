# 参照の減少と残存を確かめる実験

本番の機能ではない。[判断0037](../../docs/decisions/0037-reference-delta.md)に従い、局所的な変更から、同じ表記を使い続ける既存実装へ立ち返る材料を試す。Swift構文を決定論的に読み、LLMや対象アプリのビルドを使わない。

```sh
set -e
swift test --package-path Experiments/StructuralContext --scratch-path .build/structural-context
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-checks.json --text-output .build/context-checks.text
python3 Experiments/StructuralContext/fetch.py --manifest Experiments/StructuralContext/retrieval-inputs.json --output .build/reference-input
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/reference-oss.json --oss-input .build/reference-input
.build/structural-context/debug/context-probe .build/reference-input/alamofire-4051/before .build/reference-input/alamofire-4051/after --text
```

Swift 6以降とSwiftSyntax 603.0.1が必要。`context-probe BEFORE AFTER`はJSON、末尾の`--text`は同じ材料を罫線で表示する。Alamofire/Swift Logは[#10で既読になった入力](../../docs/validation/retrieval-holdout.md)。今回の方式の未見の有用性評価ではない。

## 表示する事実と限界

一意に対応した関数・型/ファイルのproperty bindingで、receiver付きの参照表記が減り、別の対応宣言にも両版で存在するとき、その減少/残存をまとめる。例えば`ProcessInfo.processInfo.systemUptime`が4宣言で6→0箇所、別の1宣言では2→2箇所という事実を示す。残存側は件数を維持または増加した宣言で、減った宣言は減少側にまとめる。

- 明示されたidentifier/memberの連なりとcallの引数ラベルを読み、参照位置を前後で保持する。引数の値・型・receiverの実体は同一性の判定に使わない。`.send()`、`factory().clock`等の省略/動的receiverを単純な参照へ推測しない。
- 同じ宣言内で増加した表記も添えるが、新旧が置換関係とは判定しない。残存は同じ文の維持や意味の一致を保証せず、意図的な分離/段階移行でも出る。
- 対応はfile・字句上のowner・署名による。新規/削除/改名/重複キーの宣言は対応外として件数を示す。ファイルをまたぐ移動を意味的に追わない。
- ローカル関数/型は別scopeとして読む。条件付きbodyは全て読み、条件式は解析・評価しない。init/subscript/operator/macro/type参照等は完全な索引を持たない。
- 12参照グループ、減少/残存各8宣言、各宣言4参照位置、各減少宣言6増加表記まで。JSON/textで上限と省略件数を共有する。0件は適用範囲の一貫性や設計の良さを示さない。

`contexts`が参照表記ごとの減少/残存、`unpairedBefore/After`が対応外の宣言数、`ambiguousKeys`が重複するキーの数。未解決範囲は`limitations`。単なる件数減少から「削除された正確な文」を割り当てず、宣言内の前後位置を示す。可視性・責務・PR要件や、異なるSDK間の役割の一致は推論しない。

## 入力の境界

入力配下のドット名は除外する。入力ルート/祖先の名前やFinder非表示属性は除外条件にしない。ルート自身/配下のsymlink、読取り失敗・構文エラーは終了2で部分出力せず停止。祖先symlinkは正規化して許容する。本番のGit入力/ignoreとは別の実験用ディレクトリ入力。

OSS再現には`gh`の読み取り認証とネットワークが必要。`fetch.py`は固定blobをGETで取得し、Git blob ID・SHA-256・サイズを照合する。`--manifest`省略時は旧実験の`inputs.json`なので、上記manifestを明示する。出力先は新規ディレクトリに限り、途中失敗した入力を解析しない。選択したファイルが範囲であり、全リポジトリではない。非Swiftファイルは固定資料に含むがこの抽出器は解析しない。

第三者ソースはGitへ保存せず、元のライセンスを維持する。対象アプリのコード/ビルド/スクリプトを実行せず、対象OSSへのコメント・Issue・PR・その他の変更も一切行わない。

## 以前の方式の再現

常設実装は置換し、履歴を固定commitから取り出す。class配置は`f76bfd32911fa8606f1c06d85a414a0aee8d1b7e`、変更宣言のcall接点は`c0eb0b3f783262d0c43c1f189c338174725d584b`。以下のREFを該当commitに置き換える。

```sh
set -e
mkdir -p .build/archived-context
git archive --output=.build/archived-context/input.tar REF Experiments/StructuralContext
tar -xf .build/archived-context/input.tar -C .build/archived-context
swift test --package-path .build/archived-context/Experiments/StructuralContext --scratch-path .build/archived-context/build
python3 .build/archived-context/Experiments/StructuralContext/verify.py --binary .build/archived-context/build/debug/context-probe --output .build/archived-context/result.json
```

以前の結果は[class配置](../../docs/validation/class-context-experiment.md)・[call接点](../../docs/validation/change-context-experiment.md)を参照する。
