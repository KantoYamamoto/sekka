# Git filterの実行境界: #45

2026-09-08。[判断0026](../decisions/0026-git-filter-isolation.md)。Gitのraw diffでもclean filterが起動することを、一時repoの無害なmarkerで再現した。対象repoのコードを実行しない契約を補強する。

修正後は、required clean filter・process filter・fsmonitorを設定した一時repoでもmarkerが作られず、READMEの変更を含むinventoryを取得できた。Swift 58テストとCLI/Git 39チェックが通過した。

外部filterを動かして通常Gitの正規化結果へ合わせることはしない。submoduleの内部dirty状態も調べず、親repoのgitlink変更までを対象とする。scopeとCLI仕様にこの制約を明記する。

自己利用は実装コミットと親を新旧バイナリで比較し、普通のdiffも読む。固定コミット比較はworktree filter実行の再現にはならないため、回帰の根拠は一時repoのCLIチェックと分けて扱う。Actionsと実装レビューの結果をPRで記録する。
