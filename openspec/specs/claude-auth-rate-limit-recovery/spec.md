# claude-auth-rate-limit-recovery Specification

## Purpose

确保 Claude 重新认证后的用量探测遵守服务端限流，并让界面、定时刷新和凭据监听共享一致的冷却状态，避免连续请求扩大限流窗口。

## Requirements

### Requirement: 重新认证探测遵守限流冷却
重新认证后的用量请求收到 429 时，系统 SHALL 进入与常规刷新相同的至少十五分钟 Claude 冷却期，并在冷却期内跳过新的 Claude 用量请求。

#### Scenario: 重新认证后首次探测被限流
- **WHEN** 新凭据已写入且首次 Claude 用量探测返回 429
- **THEN** 系统停止五秒重试、记录限流状态并安排冷却期结束后的单次恢复请求

#### Scenario: 凭据监听在冷却期内触发
- **WHEN** Claude 处于限流冷却期且凭据元数据再次变化
- **THEN** 系统不在冷却期内发出 Claude 用量请求

### Requirement: 限流状态替代过期认证提示
系统 MUST 在新凭据已写入但用量接口返回 429 时显示限流状态，而不是继续显示旧凭据的过期或重新登录提示。

#### Scenario: 登录成功但用量接口限流
- **WHEN** 重新认证已更新凭据且后续请求返回 429
- **THEN** Claude 用量状态显示限流信息，同时保留可用的最近真实读数
