# 公開OSSで既存構造との関係を確かめる材料

本番の機能ではなく、[検証 #56](../../docs/validation/oss-structural-context.md)の固定入力メタデータ。第三者のソースはGitへ保存せず、元のリポジトリのblobへ参照する。取得したコードにはそれぞれ元のライセンスが適用され、SekkaのMITへ変更しない。

```sh
set -e
python3 Experiments/StructuralContext/fetch.py --output .build/oss-context-input
.build/debug/sekka diff --before .build/oss-context-input/wordpress-25208/before --after .build/oss-context-input/wordpress-25208/after
.build/call-sequence-experiment/debug/call-sequence-probe .build/oss-context-input/wordpress-25208/before .build/oss-context-input/wordpress-25208/after
```

`gh`の読み取り認証・ネットワークと既存バイナリが必要。`fetch.py`はGETで固定blobを取得し、Git blob ID・SHA-256・サイズを照合する。出力先は新規に限り、途中失敗した入力を解析しない。再試行は別の新規ディレクトリへ行う。後続PRの入力は事後の照合専用で、未読レビューには渡さない。

全変更Swiftファイルと明示した関連ファイルの全文を選択している。全リポジトリではないため、参照や実装が「存在しない」とは断定できない。対象アプリのビルド・スクリプト実行はしない。対象OSSへのコメント・Issue・PR・その他の変更は一切行わない。
