## Purpose

定义构建时 Sparkle 更新源的三态配置语义，使生产构建保持兼容，同时允许本地调试构建显式禁用自动更新而不连接生产发布源。

## ADDED Requirements

### Requirement: 更新源环境变量具有三态语义
构建系统 SHALL 区分 `SU_FEED_URL` 未设置、显式为空和设置为非空 URL 三种输入。

#### Scenario: 环境变量未设置
- **WHEN** 构建环境没有定义 `SU_FEED_URL`
- **THEN** 应用使用现有生产 appcast URL

#### Scenario: 环境变量显式为空
- **WHEN** 使用 `SU_FEED_URL=` 执行构建
- **THEN** 构建产物不包含可轮询的更新源，运行时不启动自动更新检查

#### Scenario: 使用自定义更新源
- **WHEN** `SU_FEED_URL` 设置为非空 URL
- **THEN** 构建产物使用该 URL 作为 Sparkle 更新源

### Requirement: 更新兼容性保持不变
该配置能力 MUST 保持现有 Sparkle 公钥、bundle identity、版本字段和生产更新源不变。

#### Scenario: 标准发布构建
- **WHEN** CI 未覆盖 `SU_FEED_URL` 并构建正式版本
- **THEN** 现有安装仍可使用相同签名密钥和 appcast 地址发现更新
