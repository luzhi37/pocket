# 个人 Scoop Bucket

自定义 Windows 应用安装包集合，通过 [Scoop](https://scoop.sh) 管理。

## 注册

```powershell
scoop bucket add pocket https://github.com/luzhi37/pocket.git
```

## 包列表

| 名称 | 描述 | 版本 |
|------|------|------|
| [kimi-code](https://github.com/moonshotai/kimi-code) | AI coding agent CLI by Moonshot AI for terminal-based code editing, shell execution, and web retrieval. | 0.40.1 |
| [kilocode](https://github.com/Kilo-Org/kilocode) | All-in-one agentic engineering platform. Build, ship, and iterate faster with the most popular open source coding agent. | 7.5.9 |
| [plannotator](https://github.com/backnotprop/plannotator) | Annotate and review coding agent plans and code diffs visually, share with your team, send feedback to agents with one click. | 0.27.12 |

## 自动同步

仓库包含 [`.github/workflows/sync.yml`](.github/workflows/sync.yml)，每天自动检查上游最新版本并提交更新。  
另有 [`.github/workflows/validate.yml`](.github/workflows/validate.yml) 在每次推送时自动校验 manifest 格式。

## 目录结构

```
bucket/                  # Scoop 清单目录，每个包一个 JSON 文件
├── kimi-code.json
├── kilocode.json
└── plannotator.json
bin/                     # 维护工具脚本
└── sync.ps1             # 自动同步上游版本
template.json            # 新清单模板
LICENSE                  # MIT 许可证
```

## 本地开发

注册本地 bucket 后，将 `bin/sync.ps1` 配合 `-DryRun` 参数可测试更新：

```powershell
cd D:\Code\Web\pocket
.\bin\sync.ps1 -DryRun      # 模拟检查更新，不修改文件
```

详细 git 工作流见 [`GIT_WORKFLOW.md`](GIT_WORKFLOW.md)。

## 添加新包

1. 复制 `template.json` 到 `bucket/<slug>.json`
2. 填写 version、url 和 SHA256 hash
3. 运行 `scoop install D:\Code\Web\pocket\bucket\<slug>.json` 验证（需先注册本地 bucket）
4. 提交并推送
