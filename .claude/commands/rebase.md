---
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git fetch:*), Bash(git rebase:*), Bash(git merge:*), Bash(git stash:*), Bash(git push:*), Bash(git log:*), Bash(git diff:*), Read
argument-hint: (任意) --merge で rebase の代わりに merge を強制
description: 現在のフィーチャーブランチを origin/develop に追従させる (project)
---

## 現在の状況

- 引数: $ARGUMENTS

## 前提

`/feat` Step 2・`/migrate` merge 後の本実装ブランチ（A）への追従で使う rebase 処理を単体コマンド化したもの。`/feat` 実行中でなくても、フィーチャーブランチを最新の `develop` に追従させたいタイミングで随時使ってよい。

## タスク

1. **前提確認**:
   - 現在のブランチを確認する
     - **`develop` / `main` 上**: rebase 対象外。中断してユーザーに通知（フィーチャーブランチに切り替えるよう案内）
     - **フィーチャーブランチ上**: 続行
   - `git status` で未コミット変更を確認し、ある場合は **stash するか先に commit するかユーザーに確認**する（無断で stash/commit しない）

2. **共有ブランチかどうかの確認**:
   - 自分以外がこのブランチに push している可能性がある場合（複数人での共同作業、`$ARGUMENTS` に `--merge` 指定がある場合など）はユーザーに確認する
   - **共有ブランチ、または `--merge` 指定時**: rebase ではなく `git fetch origin develop && git merge origin/develop` を実行する（force-push は発生しない）
   - **単独ブランチ**: 通常どおり rebase フローに進む

3. **rebase 実行**（単独ブランチの場合）:
   - `git fetch origin develop`
   - `git rebase origin/develop`
   - migration commit を含むブランチ（`/migrate` の M が merge 済みの場合）は、同一パッチが自動 deduplicate される想定。rebase 後に `git log --oneline origin/develop..HEAD` で残った commit を確認し、想定通り deduplicate されたか報告する
   - **コンフリクト発生時は自動解消しない**。`git status` の内容をそのままユーザーに提示し、解消方法（該当ファイルを編集 → `git add` → `git rebase --continue`、または `git rebase --abort`）を案内して中断する

4. **push**:
   - rebase が成功したら `git push --force-with-lease`（`--force` は使わない）
   - merge の場合は通常の `git push`
   - リモートに他者の新しい commit が乗っていて `--force-with-lease` が拒否された場合は、無理に `--force` せずユーザーに状況を報告する

5. **結果報告**:
   - 取り込んだ `develop` 側の変更点（`git log` の要約）
   - deduplicate された migration commit の有無
   - コンフリクトで中断した場合はその旨と現在の状態

## 注意事項

- **`develop` / `main` 上では実行しない**
- **未コミット変更は無断で stash/commit しない**: 必ずユーザーに確認
- **共有ブランチでは rebase / force-push を行わない**: `git merge origin/develop` を使う
- **コンフリクトは自動解消しない**: ユーザーに委ねる
- **`--force` は使わない**: 常に `--force-with-lease`
