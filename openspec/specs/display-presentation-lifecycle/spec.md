# display-presentation-lifecycle Specification

## Purpose

确保显示模式、目标屏幕与会话锁定状态发生变化时，悬浮岛和菜单栏入口始终反映用户当前选择，且恢复会话不会重新显示已禁用的界面。

## Requirements

### Requirement: 显示模式切换立即生效
系统 SHALL 在显示模式或目标屏幕设置发生变化的同一操作周期内，按照新设置重新计算展示方式。

#### Scenario: 从 Notch 切换到 Menu Bar
- **WHEN** 用户将显示模式从 Notch 改为 Menu Bar
- **THEN** 系统隐藏悬浮岛并显示菜单栏入口，不需要第二次设置变更

#### Scenario: Automatic 的目标屏幕变化
- **WHEN** 用户处于 Automatic 模式并选择会改变解析结果的目标屏幕
- **THEN** 系统根据新目标屏幕立即选择悬浮岛或菜单栏入口

### Requirement: 解锁恢复遵守当前展示模式
系统 MUST 只在当前解析后的展示模式需要悬浮岛时，于会话解锁后恢复悬浮岛窗口。

#### Scenario: 菜单栏模式下解锁
- **WHEN** 悬浮岛曾经显示过，用户切换到 Menu Bar 模式后锁定并解锁会话
- **THEN** 悬浮岛保持隐藏，菜单栏入口保持可用

#### Scenario: Notch 模式下解锁
- **WHEN** 当前解析后的模式为 Notch 且用户解锁会话
- **THEN** 系统恢复悬浮岛窗口及其正常透明度
