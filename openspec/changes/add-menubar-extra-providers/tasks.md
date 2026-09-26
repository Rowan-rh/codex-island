## 1. 提供方选择

- [x] 1.1 `ProviderVisibilityStore` 上限改为 4，新增 `extras` 和 `toggleExtra`，`right` 改为 `count >= 2` 时取第 2 个，额外项选入左右位置时交换。验证：`ProviderConnectionTests` 覆盖上限截断、增删额外项、交换位置、只用一个提供方时清除额外项，全部通过。
- [x] 1.2 设置 → 提供商新增"更多（菜单栏显示）"一栏，补充中英文本地化。验证：编译通过；在 App 中添加两个额外提供方后，菜单栏图标显示四个提供方，灵动岛仍显示两个。

## 2. 本地化与文档

- [x] 2.1 为"显示位置"一栏以及 `Sign in with MiniMax CLI`、`Expanded` / `Collapsed` 补充翻译。验证：中文系统下设置页"显示位置"一栏全部显示中文。
- [x] 2.2 扫描全部界面代码，为面板空状态、成本页提示、概览图例等未走 `L10n` 或缺少翻译的文案补齐中英文。验证：扫描脚本不再报告缺少翻译的界面文案。
- [x] 2.3 全面更新 `README.md` / `README.zh-CN.md` 和 `docs/PROVIDERS.md`：补充 Grok、Antigravity 等全部服务，修正 Claude 凭据读取顺序，更新快捷键、设置、偏好键、隐私与故障排查，两份 README 内容保持一致。验证：人工对照代码核对事实。

## 3. 整体验证

- [x] 3.1 运行 `scripts/run-tests.sh` 和 `openspec validate add-menubar-extra-providers --strict --type change`，全部通过。
