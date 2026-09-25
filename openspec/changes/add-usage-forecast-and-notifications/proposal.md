## Why

刘海和面板只会显示当前已用百分比。用户需要自己判断照现在的速度，重置前会不会用完；全屏、切到其他桌面或在外接屏工作时，也看不到刘海变色和胶囊弹出，接近上限时容易错过。

## What Changes

- 新增用量耗尽预测：根据应用已经记录的历史读数，估算近期的消耗速度。如果照这个速度会在重置前用完，用量卡片会显示预计用完的时间；读数不够时不显示预测。不增加轮询次数。
- 新增 macOS 系统通知（可选，默认关闭）：窗口在当前重置周期内首次达到警告或严重阈值时发送通知，并附带预计用完时间；此前超过阈值的窗口重置后，发送一条"额度已重置"通知。
- 设置 → 提醒中新增"系统通知"开关，只有开启接近上限提醒后才能使用；首次打开时请求系统通知权限，权限被拒时说明如何在系统设置中开启。

## Capabilities

### New Capabilities
- `usage-forecast`: 根据已记录的读数预测额度窗口在重置前是否会用完，以及预计何时用完。
- `limit-notifications`: 在阈值首次被跨越和额度重置时发送 macOS 系统通知。

### Modified Capabilities

## Impact

- 新增 `Sources/Usage/UsageForecast.swift`（纯计算）和 `Sources/Model/SystemNotifier.swift`（UserNotifications 封装）。
- 修改 `AlertEngine`（`AlertDecision` 额外返回已重置的提供商，引擎把跨越事件和重置事件交给通知模块）、`AlertThresholdStore`（通知偏好）、`UsageView` 的 `ChartTile`（副标题显示预测）以及 `SettingsView` 的提醒区域。
- 新增中英文本地化文案，新增预测与阈值决策的单元测试。
- 不涉及网络、凭据、账本或轮询间隔的变更；通知权限由用户在系统弹窗中授予。
