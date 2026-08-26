---
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git fetch:*), Bash(git pull:*), Bash(git rebase:*), Bash(git switch:*), Bash(git checkout:*), Bash(git stash:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git log:*), Bash(git diff:*), Bash(gh pr create:*), Bash(gh pr list:*), Bash(gh pr view:*), Write, Read, Edit, Glob, Grep
argument-hint: <設計ドキュメントのパス（任意）>
description: フィーチャー実装を進めて PR まで作成する (project)
---

## 現在の状況

- 引数: $ARGUMENTS

## ブランチ構成（前提）

- base ブランチは `develop`
- ブランチ名は [CLAUDE.md](CLAUDE.md) のブランチ戦略 (`feat/`, `fix/`, `refactor/`, `docs/`, `test/`, `chore/`) に従う
- 設計ドキュメントに「マイグレーション」セクションがある場合、DB migration は `/migrate` で別ブランチ・別 PR として先行実装する（CLAUDE.md の「DB設計やスキーマ変更」の注意事項）。本コマンドはその migration が merge 済み、または並行進行中であることを前提に本実装を進める

## タスク

`/plan` で承認された設計ドキュメントに基づき、フィーチャーブランチで実装を進めて PR まで作成する。

1. **前提確認**:
   - `$ARGUMENTS` で設計ドキュメントが指定されていれば読み込む（指定が無ければユーザーに参照すべきドキュメントを確認）
   - 設計ドキュメントに「マイグレーション」セクションがあり、対応する migration PR がまだ無い場合は `/migrate` を先に実行するようユーザーに案内する
   - 現在のブランチを確認:
     - **フィーチャーブランチ上**: そのまま続行
     - **`develop` / `main` 上**: ユーザーに新規フィーチャーブランチを切るか確認（`git switch -c feat/<タスク名> origin/develop`）
     - **migration ブランチ (`/migrate` で作成したブランチ) 上**: ユーザーに本実装ブランチへの切替を確認（`/migrate` 後の戻り忘れの可能性）
   - 未コミット変更がある場合は **stash または commit をユーザーに確認**

2. **rebase develop**（フィーチャーブランチが既に存在し、develop に追随する場合）:
   - `git fetch origin develop`
   - `git rebase origin/develop` を実行
   - **コンフリクト発生時は自動解消せずユーザーに通知して中断**
   - 共有ブランチで他者が作業している場合は rebase ではなく `git merge origin/develop` を選択肢として提示
   - 単独ブランチで rebase 成功時は `git push --force-with-lease`（`--force` は使わない）

3. **実装**:
   - 設計ドキュメントに沿って実装する（対象: `api/app/` (FastAPI), `frontend/`, `infra/`）
   - 関連コード・テスト・ドキュメントを変更する
   - 設計ドキュメントから逸脱が必要な場合はユーザーに確認
   - DB 設計・スキーマ変更、認証・認可ロジック、外部 API 連携に該当する場合は [CLAUDE.md](CLAUDE.md) の「注意が必要」な領域に従い、レビュー要否をユーザーに明示する

4. **動作確認**:
   - テストコード・Lint 設定が存在する場合はそれを実行する（存在しなければスキップし、その旨をユーザーに伝える）
   - API の変更はローカルでの起動確認、フロントエンドの変更は静的ファイルの表示確認をユーザーに促す
   - [infra/README.md](infra/README.md) に影響する変更（Lambda / S3 / CloudFront 構成）がある場合はデプロイ影響をユーザーに明記する

5. **commit / push**:
   - 機能単位で commit を分割する
   - commit message は [CLAUDE.md](CLAUDE.md) のコミットメッセージ規約に従う（簡潔・冗長禁止・AI署名禁止、同一スコープはまとめる）
   - 同じブランチに `git push`（rebase 直後は `--force-with-lease`）

6. **PR 作成**:
   - 既存 PR の有無を `gh pr list --head <現在のブランチ>` で確認
   - 既存 PR があれば追加 commit を push のみ。新規作成しない
   - 新規の場合: `gh pr create --base develop --head <現在のブランチ>`
   - タイトルは [CLAUDE.md](CLAUDE.md) の「プルリクエスト」規約に従い簡潔にする
   - 本文に以下を記載:
     - 設計ドキュメントへのリンク（あれば）
     - 主要な変更点・動作確認内容
     - AI 生成コードを使用した場合はその旨とレビューで確認してほしい箇所
     - CLAUDE.md の「注意が必要」な領域に該当する場合はその旨を明記

## 注意事項

- **設計ドキュメントから逸脱する実装はユーザー確認必須**: 設計と実装の乖離を防ぐ
- **rebase コンフリクトは自動解消しない**: ユーザーに委ねる
- **共有ブランチでは rebase / force-push を行わない**: `git merge origin/develop` を選択肢として提示
- **DB 設計・認証認可・外部API連携は AI 任せにしない**: CLAUDE.md の禁止事項に従い、該当箇所は必ず人間のレビューを挟む
