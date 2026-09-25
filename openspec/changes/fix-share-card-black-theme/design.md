## Context

动机见 `proposal.md`，行为要求见 `specs/share-card-theme/spec.md`。

当前卡片颜色由 `WeeklyUsageSnapshot.tier(for:)` 计算：`WeeklyCardTier`（white / black / blue）按所选指标的总量和门槛选出等级，`WeeklyCardStyle` 再把等级映射成 `WeeklyCardTheme`（paper / midnight / cobalt）。等级还被复用在四个地方：

- `WeeklyUsageCard` 取主题，并按是否为 paper 设置 `colorScheme`；
- `WeeklyCardStudio` 把 `tier.rawValue` 写进导出文件名；
- `shareText` 用 `"%@ card"` 输出颜色名称行；
- `compactTokens` 在四舍五入会跨过 1 亿 / 10 亿门槛时向下取整，避免"暗示更高等级"。

金额里程碑 `WeeklyValueMilestone` 与等级相互独立，`money()` 自有一套防止取整虚报里程碑的保护。

## Goals / Non-Goals

**Goals:**
- 删掉等级这个概念，而不只是让它恒定返回黑色，避免留下无用的门槛和测试。
- 预览、导出和渲染测试共用同一个深色配色来源。
- 提供纯色、极光、轨道和网格四种可选深色背景；预览、分享和导出使用同一选择。

**Non-Goals:**
- 不引入浅色文字主题或按用量自动切换样式。
- 不调整卡片版式或里程碑徽章。
- 不改动金额里程碑及其取整规则。

## Decisions

### 删除 `WeeklyCardTier`，主题只保留深色
删除 `WeeklyCardTier.swift` 以及 `WeeklyUsageSnapshot.tier(for:)`。`WeeklyCardTheme` 只保留 midnight 这一种配色：删除 paper / cobalt 分支，以及 `color(for:)` 里 paper 专用的提供商颜色。`WeeklyUsageCard` 固定使用该主题，`colorScheme` 固定为 `.dark`。

备选方案：
- 保留等级、让 `tier(for:)` 恒返回 `.black`。改动最小，但留下无效的门槛常量、`thresholdLabel` 和一批恒真测试，读代码的人会以为颜色仍可变化，因此不采用。
- 保留三套随等级切换的旧主题。它会继续让时间范围和指标改变背景，因此不采用。

### 在固定深色配色下选择背景
`WeeklyCardBackdropStyle` 定义纯色、极光、轨道和网格；背景用 SwiftUI 渐变与 Canvas 绘制，避免依赖额外图片资源。工作室以缩略图选择并通过 `AppStorage` 保存选择，卡片预览与 `WeeklyCardExporter` 共用同一背景组件。未设置时默认纯色，保持旧用户熟悉的外观。

### 分享文案去掉颜色行，不找替代文字
Token 文案的 `"%@ · %@"`（卡片名 · 提供商）改为只输出提供商列表；API 文案去掉单独的卡片名行。同时从 `en` / `zh-Hans` 本地化资源中删除 `White`、`Black`、`Blue`、`%@ card`。不改成恒定的"Black card"：固定深色配色后，这个称谓不再传达任何信息。

### 文件名去掉等级字段
改为 `CodexIsland-<period>-<date>-<metric>-<format>-<background>.png`，其中背景字段来自用户选择，不代表用量等级。已保存的旧文件不受影响。

### `compactTokens` 回到常规四舍五入
去掉等级比较分支，保留 `0.99995` 的单位进位逻辑（如 999,999 显示为 1.0M，而不是 1000K）。

### 测试调整
- `WeeklyUsageSnapshotTests`：删除等级门槛、等级随筛选变化以及"取整不暗示更高等级"的断言；新增"文案不含颜色称谓"和"99,960,000 显示为 100M"的断言；金额里程碑相关断言保持不变。
- `WeeklyCardRenderHarness`：保留原来按 0.1 / 1 / 10 倍缩放的用量组合，作为不同总量的渲染样本；额外覆盖四种背景与三种比例，`verify` 校验深色背景像素和尺寸。
- `scripts/test-weekly-card.sh`：从源文件列表中移除 `WeeklyCardTier.swift`。

## Risks / Trade-offs

- [少了按用量"解锁"颜色的成就感] → 金额里程碑标题和徽章仍然保留，用来体现用量档位；以后需要时可以再加手动主题选择。
- [已经依赖文案中"XX card"字样的用户或脚本] → 这只是社交分享文案，不是接口；在 README 中同步说明即可。
- [删除 paper 专用提供商颜色后，将来再做浅色主题需要重新调色] → 可以从 git 历史中找回，这次不做预留。
- [图案干扰文字或曲线] → 背景保持低对比度，检查三种比例的 PNG 和工作室预览。

## Migration Plan

没有持久化状态或数据需要迁移。直接随版本发布；需要回退时 revert 本次提交即可。
