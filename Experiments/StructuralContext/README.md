# 追加型と既存構造の関係を確かめる実験

本番の機能ではなく、[検証 #56](../../docs/validation/oss-structural-context.md)で必要だった関係を取り出す#57の試作。[判断0034](../../docs/decisions/0034-class-context-experiment.md)に従い、追加class・親候補の空body・既存兄弟候補のoverrideを位置付きで並べる。名前の一致は解決済みの型や実行経路ではない。共通化の警告も出さない。

```sh
set -e
swift test --package-path Experiments/StructuralContext --scratch-path .build/structural-context
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-checks.json
python3 Experiments/StructuralContext/fetch.py --output .build/oss-context-input
python3 Experiments/StructuralContext/verify.py --binary .build/structural-context/debug/context-probe --output .build/context-oss.json --oss-input .build/oss-context-input
.build/structural-context/debug/context-probe .build/oss-context-input/wordpress-25208/before .build/oss-context-input/wordpress-25208/after
```

Swift 6以降とSwiftSyntax 603.0.1が必要。`context-probe BEFORE AFTER`はJSONを出す。各slotで親・兄弟・追加型のbefore/after宣言集合を並べる。同じメソッド表記は`exactSpelling`、名前・引数ラベルだけ一致する別表記は`otherSpellings`へ分け、本体のない宣言も`unavailable`として残す。空配列は入力内に該当宣言がないという意味で、実装不足とはしない。集合を示すだけで、前後メソッドの対応やコード移動を断定しない。全く候補が出なくても構造が適切だとは判定できない。

トップレベルのnongeneric classと単純なextensionだけを照合。同名型・メンバー宣言の条件分岐・限定付きextensionは保守的に候補から外す。関数本体内の#ifは宣言の有無を変えないため、この除外条件ではない。入力配下のドット名は除外するが、入力ルート/祖先の名前とFinderの非表示属性は除外条件にしない。ルート自身/配下のsymlinkと構文エラーは終了2で部分出力せず停止する。祖先symlinkは正規化して許容。本番のGit入力・ignore設定とは別。

OSS再現には`gh`の読み取り認証とネットワークが必要。`fetch.py`はGETで固定blobを取得し、Git blob ID・SHA-256・サイズを照合する。出力先は新規に限り、途中失敗した入力を解析しない。再試行は別の新規ディレクトリへ行う。後続PRの入力は事後の照合専用で、未読レビューには渡さない。第三者ソースはGitへ保存せず、元のライセンスを維持する。

全変更Swiftファイルと明示した関連ファイルの全文を選択している。全リポジトリではないため、参照や実装が「存在しない」とは断定できない。対象アプリのビルド・スクリプト実行はしない。対象OSSへのコメント・Issue・PR・その他の変更は一切行わない。
