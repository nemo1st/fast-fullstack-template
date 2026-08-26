---
allowed-tools: Bash(git status:*), Bash(git branch:*), Bash(git fetch:*), Bash(git pull:*), Bash(git rebase:*), Bash(git switch:*), Bash(git checkout:*), Bash(git stash:*), Bash(git cherry-pick:*), Bash(git add:*), Bash(git commit:*), Bash(git push:*), Bash(git log:*), Bash(git diff:*), Bash(gh pr create:*), Bash(gh pr list:*), Bash(gh pr view:*), Bash(alembic:*), Bash(pip install:*), Write, Read, Edit, Glob, Grep
argument-hint: <設計ドキュメントのパス または タスク名>
description: DB migration (SQLAlchemy + Alembic) を本実装と分離して別ブランチ・別 PR で進める (project)
---

## 現在の状況

- 引数: $ARGUMENTS

## ブランチ構成（前提）

```
develop (base)
  ├── feat/<タスク>-migration   ← M: migration のみ。先行 merge 用 PR（本コマンドはここで動く）
  └── feat/<タスク>             ← A: 本実装。M が develop に merge されたら rebase で追随
```

- CLAUDE.md の「DB設計やスキーマ変更」は上長レビュー必須・migration PR は別で作成、という規約があるため **M と A は分離する**
- M の merge を待たずに A 上で本実装を並行進行してよい（merge 順序のみ厳守: M → A）
- ブランチ名のプレフィックスは [CLAUDE.md](CLAUDE.md) のブランチ戦略に従う（`feat/` または `fix/`）

## `/migrate` の適用範囲

DB スキーマに触れる変更（テーブル・カラム・インデックス等の追加・削除・変更）はすべて `/migrate` の対象とする。DB 要素の変更を一切伴わない設計はこのコマンドの対象外。その場合はユーザーにその旨を説明し `/feat` を案内して終了する。

## タスク

1. **前提確認**:
   - `$ARGUMENTS` から設計ドキュメント（`docs/tasks/` 以下）を特定する（指定が無ければユーザーに確認）
   - 設計ドキュメントに「マイグレーション」セクションがあることを確認する。無い/不明な場合は対象外として終了し `/feat` を案内する
   - 現在のブランチと未コミット変更を確認する（未コミットがあれば stash か commit をユーザーに確認）

2. **Alembic セットアップの確認**:
   - `api/` 配下に `alembic.ini` と `migrations/`（または `alembic/`）ディレクトリが存在するか確認する
   - **未セットアップの場合**: 初回セットアップが必要な旨をユーザーに伝え、以下をユーザー承認のうえ実施する
     - `api/app/requirements.txt` に `sqlalchemy` と `alembic` を追加
     - `alembic init` でディレクトリを作成し、`env.py` から DB 接続情報（環境変数経由）を読む設定にする
     - DB 接続先（ホスト・エンジン種別など）が未確定な場合はユーザーに確認する
   - **セットアップ済みの場合**: そのまま次のステップへ

3. **M ブランチの作成**:
   - ブランチ名をユーザーに確認（デフォルト: `<A の名前>-migration`、例: `feat/user-profile-migration`）
   - `git fetch origin develop`
   - `git switch -c <M> origin/develop` で M を `develop` から派生
   - 本実装ブランチ（A）には触れない

4. **migration ファイルの作成**:
   - `alembic revision --autogenerate -m "<変更内容>"` で revision を生成する（モデル定義が無い/自動検知できない場合は `alembic revision -m "<変更内容>"` で手動作成）
   - 生成された migration ファイルの `upgrade()` / `downgrade()` 両方を確認し、`downgrade()` が未実装または不完全な場合は実装する
   - 設計ドキュメントの対象テーブル・操作種別（add / drop / alter）と整合しているか確認する
   - 完了後 commit

5. **動作確認**:
   - ローカル DB が起動していれば `alembic upgrade head` を実行して適用を確認する
   - `alembic downgrade -1` でロールバックできるか確認する
   - **develop / production DB への適用はこのコマンドでは行わない**（別途デプロイフロー経由で実施）

6. **push & PR 作成**:
   - `git push -u origin <M>`
   - `gh pr create --base develop --head <M>`
   - タイトルは [CLAUDE.md](CLAUDE.md) のコミットメッセージ規約に従い簡潔にする（例: `feat: <概要> migration`）
   - 本文に以下を記載:
     - 設計ドキュメントへのリンク
     - 対象テーブル・カラム・操作（add / drop / alter）
     - rollback 手順（`alembic downgrade -1` で戻せる旨）
     - **「レビュー必須（CLAUDE.md: DB設計・スキーマ変更は要注意領域）」を明記**
     - 「本実装ブランチ（A）と並行で進めます。本実装より先に `develop` へ merge してください」

7. **A への復帰と次コマンドの案内**:
   - 本実装ブランチ（A）が既にある場合はそこへ `git switch` で戻る案内をする（必要なら stash pop）
   - 「M が merge されたら、A 上で `git fetch origin develop && git rebase origin/develop` を実行して追随してください」と案内する

## 注意事項

- **migration PR は必ず本実装と分離する**: CLAUDE.md の禁止事項（DB設計をAI任せにする）に従い、レビューを経ずに merge しない
- **base は必ず `origin/develop`**: 別ブランチから派生させると先行 merge の意味が薄れる
- **downgrade() を必ず実装する**: rollback 不能な migration を作らない
- **develop / production DB への直接適用はこのコマンドで行わない**
- **共有ブランチでの rebase / force-push を行わない**
- **`alembic revision --autogenerate` の結果は必ず内容を確認する**: 意図しない差分が混入していないかレビューする
