# 参照差と残存位置の実験

#66 / [判断0037](../decisions/0037-reference-delta.md)。2026-09-13。**既知Alamofireで旧時間源の6→0箇所とWebSocketの2→2箇所を、同じ参照表記の1グループとして提示できた。未見の有用性は未検証。**

## 方式と範囲

#63の宣言全体のcall類似/同名候補を常設実験から置換した。入力境界とSwiftSyntaxの宣言索引を再利用し、参照差へ検索起点を変える。関数と型/ファイルのproperty bindingを前後で一意に対応付ける。receiver付き参照が減った宣言と、同じ表記が前後に存在し件数を維持/増加した別宣言を並べる。減少側で増えた参照表記も示すが、置換関係は推論しない。

対象は実験CLIのみ。本番解析/PRコメントの意味は変更せず、Actionsの既存structural-context JSON/text成果物が新試作を保存する。第三者ソースや生レビューはGit管理外、外部OSSはGET読取りのみ、対象コードは実行しない。

## 検証結果

18 Swiftテストで、部分/全移行、削除/新規、意図的分離、異なるreceiver、裸call、件数減少、trivia、overload/重複、property initializer/observer、局所scope、条件付き、動的receiver、上限/安定順序、構文エラー、表示制御文字、明示ラベル/generic型引数を確認。CLI検証は同入力の決定性、ファイル数/位置、Finder非表示属性、ドット名、構文エラー、symlink拒否を確認。

[retrieval-inputs.json](../../Experiments/StructuralContext/retrieval-inputs.json)の全108 side/blobをSHA-256へ照合し、既知2入力を通常終了で解析した。Alamofireは1グループ、Swift Logは0グループ。後者は新handler追加に対応する参照減少を入口にできず、metadata方針や責務の配置を示さない。0件を妥当性判定にしない。

Alamofireの参照は`ProcessInfo.processInfo.systemUptime`。DataRequest/DownloadRequest各2、AuthenticationInterceptorの2宣言各1が減少し、各宣言に`Instant()`が増加する。未変更の`Source/Core/WebSocketRequest.swift`内sendPingではbefore/afterとも286,296行に2参照。#10で人間相当の読解から既に得た問いを材料化した確認であり、予測や固有の見落とし削減の証拠ではない。

独立実装レビューで関数値の明示ラベルとgeneric型引数の消失を指摘され修正した。型引数内のドットをreceiverと誤る可能性も実装者が修正し対照を追加。修正後の再レビューで解消を確認。生記録は`.build/reference-delta/code-review.md`。条件付きSPI/外部要件/責務の一致は未解決で、移行漏れと断定しない。

## 自己利用

`9014fe250c17cd73c2f7deacc8e93a1b77061e25`→`2f089f37de5d925e514df74a5317fb5d4cad1d91`を本番Sekkaで比較。13変更path、6Swift、26観測、32本体未比較。旧型の撤去と新しい索引/レポートの範囲は案内されたが、参照キーの欠陥は独立レビューと通常読解から得た。mainとトップレベルテストはfile diffとして確認した。

新旧の本番バイナリSHA-256は同じ`e43a9ae5edfbeb5cd0958bb29546958e44b027e7654be7fab9747c119ab535d4`、full JSONも一致。本番機能は変わっていないため性能改善の証拠にはしない。結果と通常diff読解は`.build/self-review/reference-delta`。後続の文書/mergeコミットでSwiftを変えていないため、この検証を繰り返さない。

## 再現と次

[実験README](../../Experiments/StructuralContext/README.md)のコマンドでテスト・CLI・固定OSS照合を再現できる。ローカル結果は`.build/reference-delta/tests-qualified.log`と`verified-final.json/.text`。古いcall接点の結果は固定commitから再現する。

この入力を再調整して成功例として増やさず、実装を固定してから別の変更で評価する。特に段階移行・異なる用途が残る対照で、不要な共通化への誤誘導と読む負担を検証する。新規の別SDKユーティリティ追加など、参照減少がない元の問題一般は未解決。
