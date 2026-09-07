# 0025: 比較入力の変更一覧をSwift解析から分ける

**方針：Swift以外の変更も含む比較では、入力の変更一覧とSwiftの解析範囲を別に保持し、出力先で共有する。**

- 記録日：2026-09-08
- 状態：採用（#34）
- 関係：[0023](0023-review-entry.md)の実装契約。[0003](0003-review-coverage.md)のSwift本体coverageはそのまま別の概念として保持する。

## What / Why

CLIのdiffに `inventory.scope` と `inventory.changes` を追加し、パス・追加削除変更・解析対象の区分をcompact/full JSONで同じように返す。textとGitHub annotationsは先頭20件までと省略件数・完全版への入口を示す。PRコメントもこの一覧を使い、manifestの全変更一覧を別の正本として使わない。PR表のファイル数・観測件数・本体数は明記する。

Swiftファイルが0件でも対象外の変更が存在するときは、その変更を成功した比較結果として返す。変更もSwift入力もない場合は従来どおり明示エラー。Swiftファイルが存在して変更がない場合は0変更と表示する。構文解析したという意味の成功とは区別する。

## How — 入力範囲

- Git: 固定SHA間、またはbaseとworktreeの変更パスをGitのraw metadataから取得する。rename推定は無効にし追加/削除として扱う。バイナリ・モード変更・リンク等も含め、非通常ファイルはunsupported-file-kind、除外指定はexcludedとする。worktreeは非ignoredのuntrackedも含む。index単独の比較ではない。
- ディレクトリ: 指定root以下の通常ファイルの内容を比較する。リンクを追わず、defaultExclusionsの生成物等は探索しない。この境界をscopeに表示する。明示的な追加除外は解析の除外であり、変更一覧には残す。モードだけの変更は対象外。バイナリをUTF-8として読まず、64KiBずつバイト比較する。
- 通常ファイル探索はSwiftの読み込みと共通化する。解析本体や型照合には対象外ファイルを渡さない。

## Why not

PRコメントだけの補完やREADMEの警告ではCLI/JSONの欠落が残る。対象外の中身を意味解析する必要はない。全件を標準textへ無制限に出すことも避ける。完全一覧を残しつつ短い入口をさらに整える仕事は#35で行う。

後方互換の要件はないためPR rendererに旧manifestへのfallbackは足さず、テストfixtureも新契約へ移す。CoreのSwift snapshot直接比較にはGit等の入力範囲がないためinventoryはnilで、CLIが取得して付与する。

## 制約・見直す条件

Git入力の収集とSwift読み込みはworktreeの原子的snapshotではない。編集中の入力で厳密な再現が必要なら固定SHAを使う。既存input IDは解析したSwiftソースのIDであり、非Swift変更を含む比較全体の認証ではない。非Swiftの `--show-diff` は追加せず、通常のGit diffを使う。

ディレクトリでは大きな非Swiftファイルをバイト比較する分だけI/Oが増える。読み取り失敗は部分結果として隠さない。#35の短い表示や#38の注意集約は、inventoryの完全性と混同しない。

## 根拠

InventoryTests、実CLIのsmoke、PR rendererのテストで、対象外だけの変更・混在・除外・バイナリ・改行入りパス・モード変更・削除・リンク・空入力・表示上限を確認する。自己利用とActionsの確認は[検証記録](../validation/comparison-inventory.md)へ残す。
