# 0026: Gitの比較で対象repoのfilterを実行しない

**方針：Gitを入力の読取りに使う場合は、対象repoが指定する外部filterとfsmonitorを実行させない。**

- 記録日：2026-09-08
- 状態：採用（#45）。[0025](0025-comparison-inventory.md)の実行境界を補強する。

## What / Why

worktreeのraw Git diffは、--no-ext-diff/--no-textconvでもclean filterを呼び得る。一時repoの無害なmarkerで実行を再現した。ビルド不要・対象スクリプトを実行しない解析という契約を維持するため無効化する。

worktree比較時にGit設定はキー名だけ読み、filter driverごとのclean/smudge/processを空、requiredをfalseへ一時上書きする。Git呼出しはcore.fsmonitor=falseとする。設定ファイルは変更しない。submodule内部のdirty状態は調べず、親repoのgitlinkの変更を対象にする。

`-c key=value`で曖昧になる`=`を含むdriver名は、filterを実行する前に明示エラーとする。安全に無効化できない設定を無視して続行しない。固定commit同士ではfilterを使わないため、driverの上書きは不要。

## Why not

filterを許可して通常のGitと同じ正規化結果を得る案は、対象repoの任意プログラムを動かすため採らない。diff/textconvの無効化だけでは不足だった。Git configの値やコマンド本文を読む必要はない。

## How / 制約

ChangeInventoryのdiff起動時にdriver設定を上書きし、InputsのGit起動共通箇所でfsmonitorを無効化する。scopeへfilter無効・submodule worktree未検査を明記する。フィルタで正規化されたblobと物理ファイルの違いが、通常Gitとは異なる変更として見える場合がある。対象コードを実行せず比較するための制約である。

## 確認

CLI smokeの一時repoでrequired clean filter、process filter、fsmonitorがmarkerを作らず、READMEの変更を含む結果が得られることを確認する。既存の固定Git比較・worktree・ディレクトリ解析も全チェックで検証する。結果は[検証記録](../validation/git-filter-isolation.md)へ記録。
