## Why

当前显示模式切换、锁屏恢复、Claude 重新认证限流和调试构建更新源存在可复现的状态错误，会导致界面展示与用户设置不一致，或产生不必要的网络请求。同时，本地成本刷新每次扫描 OpenCode 全量历史并阻塞 Claude/Codex 提交，日志增长后会明显拖慢数据展示。

## What Changes

- 修正显示模式订阅时序，使 Notch、Menu Bar 和 Automatic 设置在本次操作内生效。
- 使锁屏解锁恢复遵守当前展示模式，避免隐藏的悬浮岛被重新显示。
- 将 Claude 重新认证中的 429 响应纳入统一冷却与恢复流程，并保留明确的限流状态。
- 允许 `SU_FEED_URL=` 显式生成禁用自动更新的调试构建，同时保持未设置变量时使用生产更新源。
- 将 OpenCode 日志处理改为首次完整回填、后续增量扫描，并使其与 Claude/Codex 自有日志扫描并发执行；持久化历史仍参与最终汇总。
- 增加覆盖上述状态转换、配置语义和历史保留行为的回归测试。

## Capabilities

### New Capabilities

- `display-presentation-lifecycle`: 规定展示模式切换及锁屏恢复时悬浮岛与菜单栏入口的可见性。
- `claude-auth-rate-limit-recovery`: 规定 Claude 重新认证后遇到限流时的冷却、状态展示与恢复行为。
- `update-feed-configuration`: 规定构建时更新源未设置、显式为空及自定义值的语义。
- `local-cost-refresh`: 规定本地成本首次回填、增量扫描、并发刷新及历史保留行为。

### Modified Capabilities

无。

## Impact

涉及 `DisplayPresentationController`、`IslandWindowController`、`UsageStore`、`CostStore`、`OpenCodeLogReader`、`UsageLedger`、`build.sh` 和相关测试脚本。不会修改 Sparkle 公钥、bundle ID、版本规则、Claude 凭据写入策略或最低五分钟轮询限制。
