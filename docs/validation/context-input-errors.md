# 実験CLI・診断の入力失敗境界（#98）

**同じ入力の失敗出力が揺れる場合は、保存済みstderrを整形せず、readerとerror rendererの境界を直す。** 検索方式や有用性の比較とは切り離す。[判断0006](../decisions/0006-analysis-errors.md)、[Issue #98](https://github.com/KantoYamamoto/sekka/issues/98)。

## 変更と理由

#96でFoundationのnested error表示にメモリアドレスが混じることを確認した。実験context-probeとinventory診断が同じCLI targetのformatterを使い、domain/codeと得られるpathだけを表示する。parse/usageは既存の説明を保持する。本番CLI・索引・検索条件は変更しない。

初稿の検証と独立レビューで、不正UTF-8の実入力がこのホストではCocoa code 259・userInfo空を返し、ファイル名を失うことが分かった。readerが既知のpathと「Swift sourceをUTF-8として読む」操作を補い、causeのdomain/codeはそのまま残す。259をencoding原因と断定しない。pathはquote/escapeし、一つの行で案内する。診断専用の重複formatterやstderr後処理は採らない。過去の凍結source/receiptは書き換えない。

## 検証

実装source `99e2128359650c48fbab72882c8c9ba7b10ae4dd` のown Git archiveを使った。[metadata receipt](../../Experiments/StructuralContext/Diagnostics/input-error-checks.json)にbinary・証拠のhashを残す。生ログ/レビューはignored `.build/context-input-errors/`。

- Swift Testing 85件と実験CLI 14対照が通過。追加の7失敗入力（欠落directory、非directory、不正UTF-8、parse、file/root symlink、usage）はexit 2・stdout空・stderrを含む全bytesを二回比較した。
- 新しいinventory診断の構成/build/input対照と、既存のwithdrawn-entry 37対照が通過。診断はmainのentrypointだけを置換し、reader/formatterを共有する。
- 独立レビューはCLIと診断それぞれ8失敗入力を二回実行。不正UTF-8の特殊文字filenameも含め、escape・全bytes一致を確認。初稿のpath欠落指摘は修正後に解消、未解決のコード/境界指摘なし。
- 最初の通常`swift test`はSwift Testing 85件通過後にXCTest bundle loaderが失敗し、exit 1だった。成功扱いにしない。local Swift 6.4では`--disable-xctest`でこのpackageのSwift Testing suiteを実行した。CIの通常`swift test`は変更せず、PRで別途確認する。

成功時だけでなく失敗時の決定論性を対照で確認した。任意のfilesystem競合、全てのError型、対象アプリの実行や設計の正しさを検証したものではない。

## 自己利用と完了

Sekkaでbase `8409378` → `99e2128`を比較し、Swift変更3のうち`SourceReadFailure`追加を1観測として読めた。残る2ファイルはfile diffへの入口。6 indexed bodyはtoken同一だったが、変更したtop-level catch/helperは本体比較の範囲外であり、安定した失敗表示の確認は通常diffと実入力対照による。自己利用を独立した有用性と呼ばない。

PRの最終Actions、実Botコメントと10成果物の照合、merge状態は[Issue #98](https://github.com/KantoYamamoto/sekka/issues/98)とリンクされたPRに記録する。次は[#100](https://github.com/KantoYamamoto/sekka/issues/100)で既存call入口を前後両側の共有契約へ組み直す。本番統合/M3は未見の利益確認まで保留。
