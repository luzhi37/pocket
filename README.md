# 个人 Scoop Bucket

自定义 Windows 应用安装包集合，通过 [Scoop](https://scoop.sh) 管理。

## 注册

```powershell
scoop bucket add humming-squid https://github.com/daoist/scoop-bucket-humming-squid.git
```

## 包列表

| 名称 | 描述 | 版本 |
|------|------|------|
| [kimi-code](https://github.com/moonshotai/kimi-code) | AI coding agent CLI by Moonshot AI | 0.31.1 |
| [kilocode](https://github.com/Kilo-Org/kilocode) | All-in-one agentic engineering platform | 7.4.18 |

## 添加新包

1. 在根目录创建 `<slug>.json`，填写元数据
2. 运行 `scoop test <slug>` 验证（需先注册本地 bucket）
3. 提交并推送

## 许可证

各包遵循上游项目的许可证，详见各清单中的 `license` 字段。
