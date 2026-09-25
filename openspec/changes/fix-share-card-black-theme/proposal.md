## Why

分享卡片的背景会随所选指标的总量自动在白、黑、蓝三档之间切换。用户切换时间范围、指标或服务时，颜色会跟着跳，看起来像渲染错误，还无法预期最终导出的样式。用户希望卡片保持深色风格，并能主动选择更有表现力的背景。

## What Changes

- 卡片固定使用深色文字与图表配色，背景可选纯色、极光、轨道或网格；背景不再随 API 换算价值或 token 总量变化，工作室预览与导出 PNG 保持一致。
- **BREAKING**：取消白 / 黑 / 蓝卡片等级机制，删除等级门槛（$1K / 1 亿 token、$10K / 10 亿 token）及其颜色判定。
- 分享文案不再输出"White card / Black card / Blue card"（"%@卡片"）这一行；移除随之不再使用的本地化条目。
- 导出 PNG 的文件名去掉等级字段，并加入用户选择的背景样式。
- token 紧凑数字（如 1.3B）按常规四舍五入显示，不再为避免"暗示更高等级"而向下取整；金额里程碑（`WeeklyValueMilestone`，如"四位数"）及其金额取整保护保持不变。
- 更新 README 中关于卡片配色按用量解锁的描述，并说明背景选项。

## Capabilities

### New Capabilities
- `share-card-theme`: 分享卡片在预览和导出图片中使用用户选择的深色背景，外观不随用量总量改变；分享文案不含等级称谓。

### Modified Capabilities

## Impact

- 代码：`Sources/Sharing/WeeklyCardTier.swift`（删除）、`WeeklyCardStyle.swift`、`WeeklyUsageCard.swift`、`WeeklyCardStudio.swift`、`WeeklyCardExporter.swift`、`WeeklyUsageSnapshot.swift`。
- 本地化资源：`Resources/en.lproj`、`Resources/zh-Hans.lproj` 中的 `White` / `Black` / `Blue` / `%@ card` 条目。
- 测试与脚本：`Tests/WeeklyUsageSnapshotTests.swift`、`Tests/WeeklyCardRenderHarness.swift`、`scripts/test-weekly-card.sh`、`scripts/preview-weekly-card.sh` 的源文件列表。
- 文档：`README.md`、`README.zh-CN.md`。
- 不涉及数据、网络、凭据或账本变更。
