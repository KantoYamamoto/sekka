# Git filterの実行境界: #45

[PR #46](https://github.com/KantoYamamoto/sekka/pull/46)はマージ済み。最終head `0246ba2` のActions `34185844354` が成功し、8成果物と実コメント `5579049643` のhead・変更9パスを確認した。別の実装レビュアーもCLI/Git 39チェックと固定commit間のgitlink変更保持を検証し、重要な指摘はなかった。

2026-09-08。[判断0026](../decisions/0026-git-filter-isolation.md)。Gitのraw diffでもclean filterが起動することを、一時repoの無害なmarkerで再現した。対象repoのコードを実行しない契約を補強する。

修正後は、required clean filter・process filter・fsmonitorを設定した一時repoでもmarkerが作られず、READMEの変更を含むinventoryを取得できた。Swift 58テストとCLI/Git 39チェックが通過した。

外部filterを動かして通常Gitの正規化結果へ合わせることはしない。submoduleの内部dirty状態も調べず、親repoのgitlink変更までを対象とする。scopeとCLI仕様にこの制約を明記する。

`35895ea`対親`4b0784e`を新旧バイナリで自己利用し、通常Swift diffを全て読んだ。観測3件・coverage・inventoryは一致した。filter無効化の呼出しとfsmonitorの引数は案内されたが、実行防止の正しさは通常diffとmarkerケースで確認した。固定コミット比較はworktree filter実行の再現にはならないため、回帰の根拠は一時repoのCLIチェックと分けて扱う。Actionsと実装レビューの結果をPRで記録する。
