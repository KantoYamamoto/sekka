# 公開OSSで「既存構造へ立ち返る」材料を照合

2026-09-09、[#56](https://github.com/KantoYamamoto/sekka/issues/56)。**呼び出し反復の試作は、今回の配置の問いを取り出せなかった。次は追加型と既存の親・兄弟の実装配置を結ぶ材料を検証する。** 製品への採用や有用性の証明ではない。

## 目的と選定

ユーザーのLogger/Analytics事例は非公開のため、公開OSSで代替した。主担当は公開PRの説明と後続の配置変更を読んで選定した。試作のヒット数を見る前に、WordPressの機能追加とFirefoxの局所追加を課題として固定した。後続修正を知った事後分析であり、未読PR全般のA/B比較・速度評価・欠陥率の測定ではない。

対象OSSへの操作はGitHubの読み取りのみ。コメント・Issue・PR等は一切作成せず、対象アプリのビルドもコード実行も行っていない。検証課題はSekka自身のIssueで管理する。

| 役割 | 公開PR | 固定base → head | 選択Swiftファイル数 |
| --- | --- | --- | --- |
| 機能追加時の配置 | [WordPress iOS #25208](https://github.com/wordpress-mobile/WordPress-iOS/pull/25208) | `3fd67eee55d19a17b0576f0b9fe9c3787cb7a074` → `b167166f2458a66ff015ccd6ed826561dafc28a7` | 15 → 16 |
| 後続の配置変更の照合のみ | [WordPress iOS #25855](https://github.com/wordpress-mobile/WordPress-iOS/pull/25855) | `52326781ba95a74557600f93c57cc322fd6ebdd3` → `35fff933f9c1929c2a3d00bada034fdc04925cc9` | 4 → 5 |
| 局所追加が成立し得る対照 | [Firefox iOS #34338](https://github.com/mozilla-mobile/firefox-ios/pull/34338) | `0ee840f2388fcc75a84d09e240619598f719a58f` → `0ed3b39a19b27a1d3e2e54aad9373a5125a93288` | 2 → 2 |

全変更Swiftファイルの全文に、#25208では未変更GutenbergMediaPickerHelper、#25855ではCustomPostEditorViewControllerを追加した。全repoではなく選択範囲である。非Swift変更・外部GutenbergKit・他の呼び出し元まで検証済みとはしない。Swift 6の構文解析は通るが、対象の言語設定や動作をSwift 6ビルドで確かめたわけではない。

## 再現と実行結果

[manifestとGET専用取得手順](../../Experiments/StructuralContext/README.md)で44個の前後blobを取得・検証した。Git blob ID・サイズ・SHA-256を照合し、別ディレクトリへの再取得も全44個成功。元のソースをSekkaへ転載しない。

評価器はSekka `bde71d26`時点の既存バイナリ、反復試作はPR #55の実装。両ケースとも終了0。JSONの収集件数をmanifestの前後ファイル数と照合した。秒数は計測しておらず、レビュー速度の主張はしない。

| 入力 | Sekka textのバイト数 | 反復試作の拡大件数 | 内容 |
| --- | ---: | ---: | --- |
| WordPress #25208 | 56,720 | 0 | 親と兄弟の実装の非対称な配置を結ぶ材料は出ない |
| Firefox #34338 | 3,505 | 5 | 全5件がテスト内。呼び出し→wait、assertion同士等の3→4・7→8、同一呼び出しの1→2 |

5件は構文上の反復として誤りではない。ただしこの変更で検討したい状態所有・集約先の根拠ではなく、統合警告へ昇格できない。0件も設計上の問題がないことを意味しない。

## WordPress: 問いへ進むために必要だった関係

以下は#25208のhead上のソース読解による。現行Sekkaや反復試作が自動で出した結論ではない。

1. 新しい `CustomPostEditorViewController` は `PostGBKEditorViewController` を継承する（Custom:11）。
2. 同じ親を表記する既存の `NewGutenbergViewController` にサイトメディア要求のoverrideと選択・返却処理がある（New:262–292）。
3. 親の同じdelegateメソッドは空である（PostGBK:145–147）。新しい子の選択ファイル内にはこのoverrideが見えない。
4. 既存helperはAbstractPostを受けるが、使う情報は `post.blog`（Helper:46,99）。新しい画面にAbstractPostを持たせる以外に、依存をBlogへ縮める案を検討できる。

したがって「新しい画面にもこのメディア操作が必要なら、兄弟に個別実装を追加する前に、共通ホストまたはadapterに配置できるか」という具体的な問いになる。必要機能・delegate発火条件は外部文脈であり、移動必須や実機の不具合とは断定しない。既存のMediaPickerControllerがこのdelegate経路を代替するかも未確認。

固定ソース: [新しい子](https://github.com/wordpress-mobile/WordPress-iOS/blob/b167166f2458a66ff015ccd6ed826561dafc28a7/WordPress/Classes/ViewRelated/NewGutenberg/CustomPostEditorViewController.swift#L11)、[既存の兄弟](https://github.com/wordpress-mobile/WordPress-iOS/blob/b167166f2458a66ff015ccd6ed826561dafc28a7/WordPress/Classes/ViewRelated/NewGutenberg/NewGutenbergViewController.swift#L262)、[親の空実装](https://github.com/wordpress-mobile/WordPress-iOS/blob/b167166f2458a66ff015ccd6ed826561dafc28a7/WordPress/Classes/ViewRelated/NewGutenberg/PostGBKEditorViewController.swift#L145)、[helper](https://github.com/wordpress-mobile/WordPress-iOS/blob/b167166f2458a66ff015ccd6ed826561dafc28a7/WordPress/Classes/ViewRelated/Gutenberg/GutenbergMediaPickerHelper.swift#L42)。

後続#25855では、媒体要求処理とhelper所有を親へ移し、helperの依存をBlogへ変更していた。この選択が実際に行われたことは確認できるが、#25208時点の唯一の正解とはしない。

## Firefox: 大きな再構成を求めない対照

既存の `topSitesProvider` は5種類の更新契機を同じ `fetchTopSitesDataAndUpdateState` へ送る（head:48–55）。追加した進行中window集合は同じ型にあり、同じ入口でinsertし、Taskのdeferでremoveする（:20,93–115）。全呼び出し側へ同じguardを配る変更ではない。

したがって、状態が1個増えた・switchが増えたことだけから配置のやり直しを要求する根拠は弱い。一方、既存の更新契機分類と新しい抑制対象の分類が異なるため、新たな契機追加時にどの集合へ含めるかは確認点になる。分類の一元化が必要かは、その変更頻度とポリシー次第。テストの反復5件はこの問いを表さない。

[固定ソース](https://github.com/mozilla-mobile/firefox-ios/blob/0ed3b39a19b27a1d3e2e54aad9373a5125a93288/firefox-ios/Client/Frontend/Home/Homepage/TopSites/TopSitesMiddleware.swift#L48)。動作・並行実行の安全性・全windowの網羅性は今回の検証対象外。

## 独立レビュー

レビュー専用エージェント1件が、後続PR・説明・Sekka出力を読む前に、#25208の選択ソースと通常diffから問いを記録した。その時点で上記メディア配置の問いに到達し、Blogへ依存を縮める案も挙げた。ほかに保存と一覧更新、modal中の操作抑止、cache無効化の所有について具体的な問いが出た。外部実装を未確認のため、いずれも欠陥確定とはしない。

出力との事後照合では、保存・modal・cacheには宣言変更の入口がある一方、メディア要求の兄弟間の差と未変更helperへの案内は弱く、反復0件はいずれの問いにも届かなかった。

ソース先読みなので、このレビューからSekkaによる時間短縮・固有の気づきを主張できない。選定した関係が主担当の後知恵だけではなく、元の追加から読み取れることを点検したもの。

## 次の検証と採用の境界

反復抽出の範囲を増やす案は見送る。代わりに、新しい型と既存の親・兄弟について、同じメソッド表記の宣言位置・空の本体・overrideの有無を並べる限定した材料を試す。「呼ばれる」「欠けている」「共通化すべき」という判定は出さない。空hookは意図的な場合もあり、曖昧な同名型・extension・条件コンパイルを正しく限定する必要がある。

これは新しいルールを完成品へ足す課題ではなく、既存構造を取り出す方式の検証。WordPressを説明できても同じケースに合わせた評価なので、未読の対照と別例が必要になる。Loggerの継承なしの窓口やプロジェクト全体の整合まで解決したことにはしない。成功条件0031と本番未採用の境界を維持する。

ローカル生出力は `.build/oss-structural-study/`、再取得は `.build/oss-context-reproduced/`。第三者ソースと独立レビュー生出力はGitへ含めない。
