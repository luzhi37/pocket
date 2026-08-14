# Git Workflow

本仓库的 git 流程说明。仓库特点：

- `main` 分支由 GitHub Actions 自动更新（`sync.yml` 每天 UTC 18:00 跑）。
- 所有手动修改在独立的功能分支上进行，分支名使用 `chore/<描述>` 格式，完成后删除。

---

## 日常开发流程

### 1. 创建新分支

```bash
# 拉取远程最新状态
git fetch origin

# 从最新 main 创建新分支，分支名描述本次改动
git checkout -b chore/<描述> origin/main
```

分支名示例：`chore/repo-improvements`、`chore/add-package-xxx`、`chore/fix-ci`。

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
git push origin chore/<描述> -u
```

### 5. 创建 PR 并合并到 main

```bash
# 创建 PR（自动从当前分支到 main）
gh pr create --fill

# 合并（squash，保留一条 commit）
gh pr merge --squash --delete-branch
```

> `--delete-branch` 会自动删除远程分支和本地分支。如果没有 `gh` 命令行，也可以在 GitHub 网页上操作。

### 6. 清理本地分支

如果 `gh pr merge --delete-branch` 没有自动删除本地分支，手动删除：

```bash
git branch -D chore/<描述>
```

---

## 完整示例

```bash
# 1. 创建分支
git fetch origin
git checkout -b chore/update-readme origin/main

# 2. 修改文件，多次提交
git add README.md
git commit -m "wip: update package versions"

git add AGENTS.md
git commit -m "wip: add git workflow section"

# 3. squash 为一条
git reset --soft origin/main
git add -A
git commit -m "docs: sync README and AGENTS with repo conventions"

# 4. 推送
git push origin chore/update-readme -u

# 5. 创建 PR 并合并
gh pr create --fill
gh pr merge --squash --delete-branch
```

---

## gh CLI 快速参考

| 命令 | 说明 |
|------|------|
| `gh pr create --fill` | 创建 PR，用 commit message 自动填充标题和描述 |
| `gh pr create --title "..." --body "..."` | 创建 PR，指定标题和描述 |
| `gh pr merge --squash --delete-branch` | Squash 合并并删除分支 |
| `gh pr view --web` | 在浏览器中打开当前分支的 PR |
| `gh pr list` | 列出当前仓库的 PR |

---

## 注意事项

- **不要在 `main` 上直接修改**。`main` 只接受 PR merge 和自动更新。
- 分支名用 `chore/` 前缀，保持与自动更新 commit 风格一致。
- 自动更新 workflow 的 commit 会直接推送到 `main`，你的新分支从 `origin/main` 创建时天然会包含这些更新。
- 每次改动只提交一条 commit，保持 `main` 历史清晰。