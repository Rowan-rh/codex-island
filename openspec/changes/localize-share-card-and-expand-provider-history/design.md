## Context

详见 `proposal.md` 的动机。应用语言由 `AppLanguageResolver` 决定，部分工作室文案已使用 `L10n.tr`，但卡片视图和 `WeeklyUsageSnapshot` 仍有直接写入的英文文案。Overview 组件已按 `IslandProvider.allCases` 处理图例、筛选和日期明细；缺口在历史汇总：OpenCode 提供商映射没有 DeepSeek，Overview 消费列表也未请求 DeepSeek，分享卡片历史扫描同样没有生成 DeepSeek 桶。

## Goals / Non-Goals

**Goals:**

- 让卡片工作室、卡片画布、无障碍描述及复制/分享文案使用用户选择的应用语言。
- 保持所有现有本地日志适配器的归属与去重行为，并把 DeepSeek 的 OpenCode 本地会话记录接入两个历史消费者。
- 让热力图提供商图例、单日明细及筛选在多提供商数据下仍完整可读。

**Non-Goals:**

- 不从 DeepSeek 钱包余额推导 token 数，也不调用非公开账户用量接口。
- 不新增在线数据源、凭据读取方式或提供商轮询。
- 不改变 token 统计口径、模型定价或卡片时间范围。

## Decisions

### 统一使用应用级本地化

分享工作室和卡片文案显式通过 `L10n.tr` 读取当前应用语言；日期、数字和格式化参数使用 `AppLanguageResolver.locale`。不依赖 SwiftUI 自动按系统语言查找静态字符串，因为应用允许单独覆盖 macOS 语言。里程碑标题和分享说明采用完整的本地化句子，不再用英文子串替换来改写时间范围。

### 延用现有 TokenEvent 与 UsageLedger 管线

OpenCode 记录继续先由 `OpenCodeLogReader` 归一为 `TokenEvent`，并由现有账本去重。为 DeepSeek 增加明确的提供商标识映射，把 `.deepseek` 加入 `CostStore` 的 OpenCode 汇总消费者，并在全历史卡片扫描中生成对应每日桶。Grok 与 Antigravity 继续使用各自的本地记录适配器；MiniMax CN 与 Jev 继续使用 OpenCode。`TokenEvent.Provider.deepseek` 已存在，因此不需要修改账本数据结构。

新增提供商映射前，已完成的 OpenCode 账本只会触发 30 天重叠扫描，无法补入更旧的 DeepSeek 事件。为避免升级后热力图只出现新用量，使用一个版本化的本地回填标记：当前 DeepSeek 识别版本首次扫描时暂时请求全历史；只有扫描完成且账本成功保存后才写入标记，之后恢复 30 天重叠扫描。分享卡片的全历史刷新继续使用全量扫描。

另一种做法是把所有提供商历史逻辑迁入新的通用扫描框架。当前各来源格式和持久化标识已经分开，整体重构扩大本次改动面，也不会增加用户可见能力，因此保持现有来源适配器并补齐消费者。

### Claude Code / Codex 记录按模型名归属

用户会通过 CC Switch 等工具让 Claude Code 或 Codex 调用 MiniMax、DeepSeek 模型，这些调用只出现在对应 CLI 的日志里。只按日志来源归属时，卡片和热力图会把它们算进 Claude / Codex。因此对这两个来源，模型名以 `minimax`、`deepseek` 开头（允许带 `provider/` 前缀）的事件改记到对应提供商；OpenCode 自带明确提供商 ID，不做改写。

归属在账本读出时进行，账本记录 ID、存储的提供商列和别名仍以记录工具为准，避免重复计数，规则调整时也无需迁移数据。按天恢复的整日总量（stats-cache）统计的是工具当天的全部用量，因此匹配已观测事件时按记录工具计算，被改记到其他提供商的调用仍从恢复余量中扣除。Claude / Codex 的费用、用量明细与分享卡片同一口径，数值相应减少。

### 多提供商明细优先自适应换行

保留现有按真实用量生成提供商项和筛选的行为。单日明细根据有用量的提供商数量自适应排布，避免当前固定宽度横排在多提供商时把字段挤出面板。没有本地 token 事件的提供商不生成用量项；DeepSeek 连接状态中的钱包余额仍与本地 token 历史分开。

## Risks / Trade-offs

- OpenCode 可能在部分配置中使用非标准或自定义 DeepSeek 提供商标识 → 仅识别明确约定的提供商 ID（含 `minimax`）；OpenCode 记录不基于模型名称改写归属，也不从钱包余额推算。
- 简体中文文案通常比英文更长，可能压缩卡片布局 → 在三个卡片比例、两种指标和多提供商图例下检查文本缩放与换行。
- 本地记录是否存在取决于用户实际使用的 CLI/编辑器及日志保留情况 → 继续沿用现有缺失数据和局部记录提示，不把缺少日志显示为真实零值。

## Migration Plan

无需数据库结构迁移。升级后会为 DeepSeek 归属识别执行一次成功后即完成的本地 OpenCode 全历史回填；既有去重 ID 和已保存事件保持不变。若新归属规则有误，可回退 OpenCode 提供商映射与两个汇总消费者的变更，并移除回填标记以允许重扫。

## Open Questions
