## 1. 固定深色主题

- [x] 1.1 删除 `WeeklyCardTier.swift` 与 `WeeklyUsageSnapshot.tier(for:)`；`WeeklyCardTheme` 只保留深色配色（删除 paper / cobalt 分支及 paper 专用提供商颜色），`WeeklyUsageCard` 固定使用该主题并将 `colorScheme` 设为 `.dark`。验证：`./build.sh` 编译通过，`grep -rn "WeeklyCardTier\|\.paper\|tier(for" Sources` 无结果。
- [x] 1.2 `WeeklyCardStudio` 的导出文件名去掉等级字段，改为 `CodexIsland-<period>-<date>-<metric>-<format>-<background>.png`。验证：代码中的文件名模板不再引用等级。
- [x] 1.3 增加纯色、极光、轨道、网格四种深色背景，工作室提供缩略图选择并保存偏好，预览、分享与导出共用同一背景。验证：在演示窗口切换四种样式，并检查导出图。

## 2. 文案与数字格式

- [x] 2.1 `shareText` 两种指标都去掉卡片颜色称谓行（Token 文案只保留提供商列表），并从 `en` / `zh-Hans` 的 `Localizable.strings` 删除 `White`、`Black`、`Blue`、`%@ card`。验证：在 `WeeklyUsageSnapshotTests` 中断言两种指标的文案都不含 "card"，且提供商列表仍然存在。
- [x] 2.2 `compactTokens` 去掉等级比较分支，保留单位进位逻辑。验证：新增断言 99,960,000 显示为 "100" + "M"，999,999 仍显示为 M 单位；金额里程碑取整断言保持通过。

## 3. 测试与文档

- [x] 3.1 更新 `WeeklyUsageSnapshotTests`：删除等级门槛与等级筛选断言；`scripts/test-weekly-card.sh` 移除 `WeeklyCardTier.swift`。验证：`bash scripts/test-weekly-card.sh` 全部通过。
- [x] 3.2 更新 `WeeklyCardRenderHarness`：保留 0.1 / 1 / 10 倍用量的渲染样本，增加四种背景与三种比例的样本，`verify` 校验深色背景和尺寸。验证：`bash scripts/preview-weekly-card.sh` 输出 60 张 PNG 渲染 PASS，并检查极光、轨道和网格样图。
- [x] 3.3 更新 `README.md`、`README.zh-CN.md`，删除"配色按用量解锁"的描述，说明四种深色背景。验证：`grep -n "earned\|白卡\|蓝卡" README*.md` 不再出现卡片配色说明。

## 4. 整体验证

- [x] 4.1 运行 `scripts/run-tests.sh`（此前的测试通过，随后在已知的 `pricing-catalog-race-tests` 段错误处停止），并在演示窗口切换 7 天 / 30 天、两种指标、服务勾选与背景，确认卡片始终为深色。`openspec validate fix-share-card-black-theme --strict --type change` 通过。
