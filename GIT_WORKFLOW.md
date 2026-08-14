# Git Workflow

本仓库的 git 流程说明。仓库特点：

- `main` 分支由 GitHub Actions 自动更新（`sync.yml` 每天 UTC 18:00 跑）。
- 所有手动修改统一在 `chore/readme-sync` 分支上进行，保持远程分支名整洁。

---

## 日常开发流程

### 1. 开始新一批修改

```bash
# 拉取远程最新状态
git fetch origin

# 将 chore/readme-sync 重置到 origin/main（丢弃上一次的旧改动）
git checkout -B chore/readme-sync origin/main
```

`-B` 会强制重置已有分支，效果等同于删除重建。

### 2. 修改并提交（开发阶段）

开发过程中可以多次提交，方便追踪进度：

```bash
# 修改文件...

# 按逻辑分步提交
git add <文件路径>
git commit -m "wip: 具体改动说明"
```

### 3. 推送前压缩为一条 commit

每次 push 前，必须将本周期所有 commit 压缩为一条，保持远程历史整洁：

```bash
# 将分支指针重置到 origin/main，但保留所有改动在工作区
git reset --soft origin/main

# 提交为一条 commit
git add -A
git commit -m "类型: 简短描述"
```

> `git reset --soft origin/main` 会把分支移回 `origin/main` 的位置，但所有已暂存和未暂存的改动都保留在工作区。然后一次性提交，效果等同于把周期内所有改动压缩成一条。

提交信息格式（conventional commits）：

```
feat: ...     新功能
fix: ...      修复
chore: ...    杂项（自动更新、配置、文档等）
docs: ...     文档
refactor: ... 重构
```

### 4. 推送到远程

```bash
git push origin chore/readme-sync --force
```

> 因为每次重置到 `origin/main` 并 squash，`chore/readme-sync` 的历史会被重写，所以必须用 `--force`（或 `--force-with-lease`）。单人分支，安全。

### 5. 创建 PR 并合并到 main

在 GitHub 上打开 `chore/readme-sync → main` 的 PR，审核后合并。

合并后，远程的 `chore/readme-sync` 分支可以留着，下次开始新工作时执行第 1 步即可重置。

---

## 完整示例

```bash
# 开始新工作
git fetch origin
git checkout -B chore/readme-sync origin/main

# 修改多个文件，过程中分多次提交
git add README.md
git commit -m "wip: update package table"

git add AGENTS.md
git commit -m "wip: add git workflow section"

# 推送前 squash 为一条
git reset --soft origin/main
git add -A
git commit -m "docs: sync README and AGENTS with repo conventions"

# 推送
git push origin chore/readme-sync --force
```

---

## 注意事项

- **不要在 `main` 上直接修改**。`main` 只接受 PR merge 和自动更新。
- **`--force` 只用于 `chore/readme-sync`**，不要对 `main` 使用。
- 如果多人协作（目前是单人），注意 `--force` 会覆盖远程历史，其他人需要 rebase。
- 自动更新 workflow 的 commit 会直接推送到 `main`，你的分支在 reset 时天然会包含这些更新。