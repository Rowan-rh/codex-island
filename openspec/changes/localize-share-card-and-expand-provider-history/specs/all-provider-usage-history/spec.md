## Purpose

让热力图及用量卡片历史反映本地可读取的全部已支持提供商会话记录，并在提供商筛选和日期详情中保持归属清晰。

## ADDED Requirements

### Requirement: 热力图汇总所有已支持的本地用量记录
系统 SHALL 将 Claude、Codex、Grok、Antigravity、MiniMax CN、DeepSeek 和 Jev 的可读取本地会话记录纳入相应用量历史。DeepSeek 用量 SHALL 仅来自明确归属于 DeepSeek 的本地会话记录，不得从钱包余额或非公开账户接口推算。

#### Scenario: 已支持日志中存在提供商用量
- **WHEN** 任一已支持提供商的本地记录适配器读取到有效 token 用量
- **THEN** 该用量按提供商和本地日期计入 Overview 热力图汇总

#### Scenario: DeepSeek OpenCode 会话
- **WHEN** OpenCode 本地会话记录的提供商标识为 DeepSeek 且包含有效 token 用量
- **THEN** 该记录计入 DeepSeek 的每日历史和对应的用量卡片统计

#### Scenario: 查看某日的提供商明细
- **WHEN** 用户选择包含多个提供商记录的热力图日期
- **THEN** 日期明细、提供商汇总和提供商筛选均显示各自有记录的提供商与其用量，且布局能容纳多项

#### Scenario: 提供商没有本地 token 记录
- **WHEN** 某提供商在所选期间没有可读取的本地 token 记录
- **THEN** 系统不以钱包余额、订阅额度或缺失数据伪造 token 用量，也不将其作为有用量的提供商显示

#### Scenario: 历史记录重复扫描
- **WHEN** 同一本地会话记录被再次扫描并汇总
- **THEN** 热力图和卡片中的该记录只计入一次
