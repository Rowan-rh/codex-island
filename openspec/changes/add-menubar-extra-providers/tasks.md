## 1. 提供方选择

- [x] 1.1 `ProviderVisibilityStore` 上限改为 4，新增 `extras` 和 `toggleExtra`，`right` 改为 `count >= 2` 时取第 2 个，额外项选入左右位置时交换。验证：`ProviderConnectionTests` 覆盖上限截断、增删额外项、交换位置、只用一个提供方时清除额外项，全部通过。
- [x] 1.2 设置 → 提供商新增"更多（菜单栏显示）"一栏，补充中英文本地化。验证：编译通过；在 App 中添加两个额外提供方后，菜单栏图标显示四个提供方，灵动岛仍显示两个。

## 2. 本地化与文档

- [x] 2.1 为"显示位置"一栏以及 `Sign in with MiniMax CLI`、`Expanded` / `Collapsed` 补充翻译。验证：中文系统下设置页"显示位置"一栏全部显示中文。
- [x] 2.2 更新 `README.md` / `README.zh-CN.md`。验证：两份 README 都说明菜单栏图标最多显示四个提供方。

## 3. 整体验证

- [x] 3.1 运行 `scripts/run-tests.sh` 和 `openspec validate add-menubar-extra-providers --strict --type change`，全部通过。
