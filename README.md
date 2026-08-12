# 个人 Scoop Bucket

自定义 Windows 应用安装包集合，通过 [Scoop](https://scoop.sh) 管理。

## 注册

```powershell
scoop bucket add personal https://github.com/luzhi37/pocket.git
```

## 包列表

| 名称 | 描述 | 版本 |
|------|------|------|
| [kimi-code](https://github.com/moonshotai/kimi-code) | AI coding agent CLI by Moonshot AI for terminal-based code editing, shell execution, and web retrieval. | 0.35.0 |
| [kilocode](https://github.com/Kilo-Org/kilocode) | All-in-one agentic engineering platform. Build, ship, and iterate faster with the most popular open source coding agent. | 7.4.21 |
| [plannotator](https://github.com/backnotprop/plannotator) | Annotate and review coding agent plans and code diffs visually, share with your team, send feedback to agents with one click. | 0.26.8 |

## 自动同步

仓库包含 [`.github/workflows/sync.yml`](.github/workflows/sync.yml)，每天自动检查上游最新版本并提交更新。

## 目录结构

```
bucket/                  # Scoop 清单目录，每个包一个 JSON 文件
├── kimi-code.json
├── kilocode.json
└── plannotator.json
scripts/                 # 工具脚本
├── template.json        # 新清单模板
├── update.ps1           # 重新生成索引并验证
└── sync.ps1             # 自动同步上游版本
```

## 添加新包

1. 复制 `scripts/template.json` 到 `bucket/<slug>.json`
2. 填写 version、url 和 SHA256 hash
3. 运行 `scoop test <slug>` 验证（需先注册本地 bucket）
4. 运行 `.\scripts\update.ps1` 重新生成索引
5. 提交并推送
