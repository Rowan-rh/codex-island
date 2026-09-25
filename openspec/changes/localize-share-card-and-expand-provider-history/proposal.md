## Why

分享卡片的界面和导出图片仍有英文文案，中文用户需要一张完整可读的中文卡片。Overview 热力图已能按提供商着色和筛选，但本地历史管线没有纳入所有已有记录适配器及 OpenCode 中的 DeepSeek 记录，导致部分提供商的用量无法出现在热力图和卡片历史中。

## What Changes

- 分享卡片工作室、卡片图片、导出标题和分享文案按应用当前语言显示中文或英文。
- 将所有现有本地会话记录适配器及可识别的 OpenCode 提供商记录纳入用量历史汇总。
- 在热力图、日期详情和分享卡片中展示有真实本地记录的提供商；没有记录的提供商继续保持缺失，不显示为零用量。
- DeepSeek 只使用 OpenCode 本地会话记录；不把钱包余额解释为 token 用量，也不读取非公开的账户用量接口。

## Capabilities

### New Capabilities
- `share-card-localization`: 分享卡片工作室、卡片渲染结果和导出文案遵循应用语言设置。
- `all-provider-usage-history`: 热力图和分享卡片历史涵盖所有有本地会话记录支持的提供商。

### Modified Capabilities

## Impact

- 影响 `Sources/Sharing/` 的卡片工作室、图片渲染、日期与分享文案及历史扫描；影响 `Sources/Cost/CostStore.swift`、`Sources/Cost/OpenCodeLogReader.swift` 和 `Sources/Views/OverviewView.swift` 的提供商历史数据流。
- 扩展本地 OpenCode 记录的提供商归属识别和日汇总；不增加网络端点或凭据访问。
- 补充简体中文本地化资源及相关行为测试。
