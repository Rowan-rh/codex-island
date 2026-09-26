## ADDED Requirements

### Requirement: 最多选择四个提供方
系统 SHALL 允许用户最多选择四个提供方。第 1、2 个 SHALL 对应灵动岛和展开面板的左右位置；第 3、4 个 SHALL 只在菜单栏图标中显示。已保存的设置中无效或重复的提供方 MUST 被移除，超过四个的部分 MUST 被截断。

#### Scenario: 旧设置升级
- **WHEN** 已有用户升级后，保存的设置中只有两个提供方
- **THEN** 灵动岛、展开面板和菜单栏图标的显示与升级前一致

#### Scenario: 保存了超过四个提供方
- **WHEN** 保存的设置中有五个不重复的有效提供方
- **THEN** 系统只保留前四个

### Requirement: 添加和移除额外提供方
在已经选择左右两个提供方时，设置 → 提供商 SHALL 显示"更多（菜单栏显示）"一栏，允许添加尚未选择的提供方，直到总数达到四个，也允许逐个移除额外提供方。左右位置上的提供方 MUST NOT 通过这一栏移除。

#### Scenario: 添加额外提供方
- **WHEN** 用户已选择 Claude 和 Codex，并在"更多"中添加 Grok
- **THEN** 菜单栏图标依次显示 Claude、Codex、Grok，灵动岛仍只显示 Claude 和 Codex

#### Scenario: 达到上限
- **WHEN** 已选择四个提供方
- **THEN** "添加提供方"按钮不再显示

#### Scenario: 只用一个提供方
- **WHEN** 用户在右侧位置选择"无——只用一个提供方"
- **THEN** 系统只保留左侧提供方，额外提供方一并清除

#### Scenario: 把额外提供方选入左右位置
- **WHEN** 已选择 Claude、Codex、Grok，用户把左侧位置改为 Grok
- **THEN** Grok 与 Claude 交换位置，结果为 Grok、Codex、Claude

### Requirement: 显示位置设置跟随界面语言
设置中"显示位置"一栏的标题、选项（自动 / 刘海 / 菜单栏）和说明文字 SHALL 使用当前界面语言显示。

#### Scenario: 中文系统
- **WHEN** 界面语言为简体中文
- **THEN** "显示位置"一栏全部显示中文
