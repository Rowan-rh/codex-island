## 1. 用量预测

- [x] 1.1 新增 `UsageForecast`（纯函数）：只用当前周期的读数、近 1 小时或 24 小时的斜率，跨度不足 15 分钟不预测。验证：新增单元测试覆盖会用完、撑得到重置、读数不足、周期回落、长窗口、已满 100%、有错误等情况，全部通过。
- [x] 1.2 `ChartTile` 在预测会用完时，把副标题改为"约 HH:mm 用完 · X 后重置"（Numeric 用紧凑版），并补充中英文本地化。验证：编译通过；用演示数据渲染面板，确认副标题正确、没有溢出。

## 2. 阈值决策与通知

- [x] 2.1 `AlertDecision.evaluateCrossings` 返回 `resets`（旧周期达到过警告阈值、新读数低于警告、重置时间晚 10 分钟以上）。验证：单元测试覆盖用到上限后重置、普通重置、重置时间抖动三种情况。
- [x] 2.2 新增 `SystemNotifier` 并在 `AlertThresholdStore` 中加入 `notificationsEnabled`；`AlertEngine` 在 warmup 结束后把跨越和重置事件交给它。验证：编译通过；没有 bundle identifier 的测试程序不访问通知中心。
- [ ] 2.3 在设置的提醒区域加入"系统通知"开关、授权请求和被拒提示，并补充中英文本地化。验证：编译通过；在 App 中打开开关，出现系统授权弹窗，授权后能收到一条测试跨越的通知。

## 3. 文档与整体验证

- [x] 3.1 更新 `README.md` / `README.zh-CN.md` 的功能列表。验证：两份 README 都提到预测和系统通知。
- [x] 3.2 运行 `scripts/run-tests.sh`（`pricing-catalog-race-tests` 的段错误是已知问题）和 `openspec validate add-usage-forecast-and-notifications --strict --type change`，全部通过。
