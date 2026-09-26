# CodexIsland

[English](README.md) | [简体中文](README.zh-CN.md)

<p align="center">
  <img src="Assets/codexisland-logo.png" width="160" alt="CodexIsland logo">
</p>

> 你的 AI 用量限额，住在 Mac 刘海里。

CodexIsland 是一个原生 macOS 悬浮层，把 MacBook 刘海变成类似 Dynamic Island 的实时状态，显示 AI 用量限额和账户状态。平时它安静地贴在刘海上，鼠标悬停时展开预览，点击后打开完整面板：各服务的额度或钱包余额、图表样式、根据本地日志估算的成本，以及全年用量日历。没有刘海的 Mac 上，或者你更喜欢菜单栏时，它会以菜单栏图标的形式出现。

https://github.com/user-attachments/assets/195beeff-0f70-4d6b-8f3d-9f31d9c0b989

应用免费、开源、未签名，并且以本地优先为原则。它只读取你已经在用的官方 CLI 和桌面应用写入本机的凭据，也只调用各服务自己的用量接口。

## 支持的服务

| 服务 | 灵动岛上显示 | 数据来源 |
| --- | --- | --- |
| Claude | 5 小时与每周额度、订阅方案 | Claude Code 凭据（只读） |
| Codex | 5 小时与每周额度（或只有每周）、重置额度券 | `~/.codex/auth.json` |
| Grok | 当前计费周期的订阅额度使用率 | `~/.grok/auth.json` 中的 Grok CLI 会话 |
| Google Antigravity | 可选模型组的额度窗口 | `agy` CLI 的钥匙串条目 |
| MiniMax CN | Token Plan 的 5 小时与每周窗口 | `mmx` CLI 配置或 `MINIMAX_CN_API_KEY` |
| DeepSeek | API 钱包余额 | `DEEPSEEK_API_KEY` 或 DeepSeek Harness |
| Jev | 今天和本月的本地 token 用量 | 仅本地 OpenCode 记录 |

灵动岛左右两侧各放一个服务，菜单栏图标最多可显示四个。只要对应的 CLI 在本机留有用量日志，每个服务都会出现在成本和概览页面中。各服务接入的详细说明见 [docs/PROVIDERS.md](docs/PROVIDERS.md)。

## 功能

### 灵动岛与菜单栏

- **贴合刘海的悬浮层。** 紧凑状态是一个对齐物理刘海的黑色胶囊，使用和硬件一致的连续圆角。
- **悬停预览。** 轮廓会展开到刚好显示每个服务当前窗口的百分比和重置倒计时；开启 **始终显示使用量** 后，不悬停也会一直显示。
- **点击展开。** 打开完整面板，包含各服务列、图表控制，以及可以点击立即刷新的同步状态。
- **显示位置。** 可选 **自动**、**刘海** 或 **菜单栏**。自动模式在内置刘海屏上使用灵动岛，连接外接显示器时切换为菜单栏图标。菜单栏模式会完全隐藏灵动岛，图标上显示各服务的标志和百分比，点击即可打开同样的完整面板。
- **菜单栏最多显示四个服务。** 除了灵动岛左右两个位置，还可以在 **设置 → 服务 → 更多（菜单栏显示）** 中再添加两个。
- **选择显示器。** 自动选择带刘海的显示器，或把灵动岛固定到某台已连接的显示器上。没有刘海的显示器可以选择紧凑宽度或刘海宽度。
- **不遮挡岛外点击。** 窗口会忽略可见轮廓以外的鼠标事件，菜单栏和后面的应用仍能正常操作。

### 用量

- **三个可滑动的页面。** 横向滑动、点击底部圆点、按 ←/→ 或 ⌘1–⌘3，在 **用量**、**成本** 和 **概览** 之间切换。
- **五种图表样式。** Ring、Bar、Stepped、Numeric、Sparkline。可以在设置中选择默认样式，也可以在展开面板中按住 Command 点击循环切换。Sparkline 使用 CodexIsland 每次成功刷新时记录的真实读数。
- **已用或剩余。** 额度窗口可以显示为已用百分比或剩余百分比。
- **耗尽预测。** 如果按最近的消耗速度，某个窗口会在重置前用完，用量卡片会显示大约何时用完。速度来自应用已经记录的读数，不会增加轮询；当前周期的历史不足 15 分钟时不显示预测。
- **Codex 重置额度券。** 有可用的重置额度券时，用量页底部会显示数量和过期时间。
- **有提示的空状态。** 某个服务没有读数时，会显示"无有效订阅"或"用量不可用"，并提供跳转到设置的入口，而不是显示虚假的 0%。

### 成本与历史

- **本地成本估算。** 成本页根据本地 Claude Code、Codex CLI、OpenCode、Grok CLI 和 Antigravity CLI 的数据，估算今天和本月至今的花费与 token 吞吐量，可以按美元、API 价值、token 数或趋势显示。金额可以显示为 USD、CNY、EUR、GBP、JPY、KRW、CAD、AUD 或 CHF。
- **全年一览。** 概览页用类似 GitHub 贡献图的日历展示今年的活动，数据来自所有支持的服务的日志，与灵动岛上选了哪些服务无关。点击图例中的某个服务可以只看它的历史，再点一次恢复显示全部。
- **值得分享的用量卡片。** 从 **概览 → 分享用量** 或 **设置 → 通用 → 用量卡片** 打开。以美元 API 换算价值为主角，配上流动的累计曲线和各服务金额，也可以改为突出 token 数。背景可选深色 **纯色**、**极光**、**轨道** 或 **网格**；时间范围可选 **最近 7 天**（默认）、**最近 30 天**、**最近 3 个月**、**今年** 或 **全部时间**；可选动态 / 方形 / 故事比例和署名；然后通过 macOS 分享菜单发送，保存 1080 像素宽的 PNG，或复制图片和文案。应用更新后，有本周用量时会自动打开一次。数据按本地日历统计并包含缓存；API 价值是估算值，不是你的订阅账单。全部内容都在你的 Mac 上生成。
- **用量历史属于你自己。** CodexIsland 会把采集到的 token 数保存在自己的本地数据库中，即使服务清理了日志，历史也不会丢失；重复扫描只会更新同一次调用，不会重复计数。详见 [用量历史存储](docs/USAGE-HISTORY.md)。**设置 → 通用 → 恢复 Claude 用量…** 可以从残留日志、备份和旧的每日快照中找回经过校验的用量，确认预览后再导入；也提供了 [终端脚本](docs/USAGE-HISTORY.md#recover-your-claude-usage)。
- **可配置 token 统计口径。** TOKENS 主数字可以统计所有 token（包含缓存，与 ccusage 一致），也可以只统计输入 + 输出，与 Anthropic claude.ai 的统计面板一致。

### 提醒

- **接近上限提醒。** 可选的警告和严重阈值：可见窗口超过阈值时，灵动岛光晕变为琥珀色或红色，并自动弹出一次预览胶囊。
- **系统通知。** 可选的 macOS 通知：窗口首次超过阈值时提醒（附带预计用完时间），曾达到警告阈值的窗口重置后也会通知。在 **设置 → 通用 → 提醒** 中开启。
- **钴蓝光晕与低功耗模式。** 刷新进行中时灵动岛周围会有柔和的光晕，一分钟没有活动后自动停下。低功耗模式会隐藏常驻光晕，只在刷新、悬停或提醒时显示。

### 应用

- **英文与简体中文。** 默认跟随 macOS 系统语言，也可以在设置中手动选择。
- **无 Dock 图标的设置窗口。** 点击展开面板里的齿轮（或按 ⌘,）打开自定义设置窗口，分为通用、显示、服务三个标签页。
- **安全的轮询间隔。** 支持 5 分钟、15 分钟、30 分钟。不提供低于 5 分钟的选项，因为 Anthropic 对用量接口的限流非常严格。
- **Sparkle 自动更新。** 在后台检查最新 GitHub Release 附带的 appcast，安装前会提示确认。更新使用 EdDSA 密钥签名，无需 Apple 签名体系即可校验。如果想固定版本，可以在设置中关闭自动检查。
- **通用二进制。** `build.sh` 会分别编译 arm64 和 x86_64 切片，再用 `lipo` 合并，最低支持 macOS 13。
- **原生应用的隐私边界。** 没有遥测、没有崩溃上报、没有第三方分析，也没有代理服务。

## 安装

### Homebrew

```sh
brew install --cask ericjypark/tap/codexisland
```

首次运行会自动 tap `ericjypark/homebrew-tap`。这个 cask 会自动移除 Gatekeeper quarantine 属性（CodexIsland 没有 Apple 签名，更新校验由 Sparkle 独立完成）。

### 直接下载

从 [最新 Release](https://github.com/ericjypark/codex-island/releases/latest) 下载 `CodexIsland-X.Y.Z.dmg`，把应用拖进 `/Applications`，然后运行：

```sh
xattr -dr com.apple.quarantine /Applications/CodexIsland.app
```

<details>
<summary>为什么需要移除 quarantine？</summary>

CodexIsland 未签名，因为 Apple Developer ID 证书每年需要 99 美元，而这是一个免费的开源项目。上面的命令会移除 macOS Gatekeeper 的 quarantine 属性，避免出现"无法打开，因为 Apple 无法检查其是否包含恶意软件"的拦截。源码就在这个仓库里，可以自行审计。

如果将来通过 [GitHub Sponsors](https://github.com/sponsors/ericjypark) 获得 Apple Developer ID，就可以提供签名版本。
</details>

<details>
<summary>不想用终端怎么办？</summary>

1. 把 `CodexIsland.app` 拖进 `/Applications`。
2. 尝试打开一次，macOS 会因为未签名而拦截。
3. 打开 **系统设置 → 隐私与安全性**。
4. 滚动到底部，找到被拦截的 CodexIsland 提示。
5. 点击 **仍要打开**，然后重新启动应用。
</details>

## 首次运行

CodexIsland 不会询问密码或 API Key。它只读取你已经登录过的命令行工具或桌面应用的认证状态，也从不自行写入、轮换或刷新其他工具的凭据。

**Claude**

- 运行一次 `claude`，让 Claude Code 保存凭据。
- CodexIsland 依次检查 `CLAUDE_CODE_OAUTH_TOKEN`、Claude Code 写入 macOS 钥匙串的条目（`Claude Code-credentials`，以及按 `CLAUDE_CONFIG_DIR` 区分的变体），最后回退到 `$CLAUDE_CONFIG_DIR/.credentials.json`。
- 凭据访问严格只读。如果存储的 token 已过期且没有工具在刷新它（例如你只使用 Claude 桌面应用），CodexIsland 会在每次过期时运行一次 `claude -p "ok" --model haiku`，让 CLI 自己刷新登录。如果用量接口要求新的授权范围，请运行 `claude /login`。
- 找不到任何凭据时，面板显示 `auth required — run claude`。

**Codex**

- 先登录 Codex / ChatGPT CLI。
- CodexIsland 读取 `~/.codex/auth.json`。
- 文件或 access token 缺失时，面板显示 `no codex auth`。

**Grok**

- 用你的 Grok 订阅账号通过官方 Grok CLI 登录（`grok login`）。只在 grok.com 网页登录是不够的。
- CodexIsland 读取 `$GROK_HOME/auth.json`（默认 `~/.grok/auth.json`）。会话过期时会运行一次 `grok models`，让 CLI 自己续期。

**Google Antigravity**

- 通过官方 `agy` CLI 登录，不需要桌面应用。
- CodexIsland 读取 CLI 的钥匙串条目（`gemini` / `antigravity`）。会话过期时会运行一次 `agy models`，让 CLI 自己续期。
- 可以在设置中选择要显示的模型组和指标。

**MiniMax CN**

- 通过官方 MiniMax CLI 登录（`mmx auth login --recommend --region=cn`），或设置 `MINIMAX_CN_API_KEY`。
- CodexIsland 读取 CLI 的 `~/.mmx/config.json`（或 `MMX_CONFIG_DIR` 指定的目录）。请使用 MiniMax 中国区订阅 Key，不要使用普通按量计费的 API Key。

**DeepSeek**

- 设置 `DEEPSEEK_API_KEY`，或通过 DeepSeek Harness 保存（`$DSH_HOME/.credentials.yaml`，默认 `~/.dsh/.credentials.yaml`）。
- 只显示钱包余额，不调用私有控制台接口，也不读取浏览器会话。

**Jev**

- CodexIsland 读取 OpenCode 本地会话中服务为 Jev 或 TypeSafe 的记录，显示今天和本月的 token 用量。
- 应用中 Jev 没有账户额度，也从不读取它的凭据。

应用启动后会立即进行第一次拉取，所以第一次悬停时通常已经有数据。打开设置也会触发一次刷新。

## 使用

- 悬停刘海预览当前用量，移开鼠标即收起。
- 点击灵动岛（或菜单栏图标）打开完整面板。
- 横向滑动、点击底部圆点、按 ←/→ 或 ⌘1–⌘3，在 **用量**、**成本** 和 **概览** 之间切换。
- 在展开面板中按住 Command 点击，循环切换当前页面的图表样式（用量页：Ring/Bar/Stepped/Numeric/Sparkline；成本页：USD/VALUE/TOKENS/TREND；概览页只有日历一种视图）。
- 点击面板顶部的 `synced Xs ago` 立即刷新。
- 点击展开面板左下角的齿轮，或按 ⌘,，打开设置。
- 鼠标在灵动岛上时按 ⌘Q 退出，也可以在设置中退出。

选择显示哪些服务只影响显示。应用会在内存中保留最新数据，重新显示某个服务时不会从零开始。

## 设置

设置窗口是自定义的 `NSWindow`，不是系统 Settings scene。应用以无 Dock 图标的 accessory app 方式运行；菜单栏模式下会显示状态栏图标，而不是刘海悬浮层。

- **通用：** 登录时启动、5/15/30 分钟刷新间隔、应用语言、始终显示使用量、低功耗模式、用量卡片、恢复 Claude 用量、接近上限提醒与系统通知，以及 Sparkle 更新设置。
- **显示：** 自动 / 刘海 / 菜单栏显示位置、已用或剩余百分比、用量页和成本页的图表样式、目标显示器，以及无刘海显示器上的灵动岛宽度。
- **服务：** 灵动岛左右两侧的服务、菜单栏额外显示的最多两个服务、各服务的连接状态和登录操作、token 统计口径、成本货币，以及手动刷新本地成本数据。

货币换算使用本地缓存的每日参考汇率，底层模型价格和成本计算仍以美元为准。汇率与模型价格采用相同的更新节奏：启动时读取缓存，每六小时检查一次，缓存超过 24 小时才重新获取。离线时保留最近一次有效的汇率表；还没有汇率表时显示美元。

主要偏好保存在 `UserDefaults` 的 `MacIsland.*` 键下：

| 设置 | Key | 取值 |
| --- | --- | --- |
| 服务（有序） | `MacIsland.selectedProviders` | 最多四个：`claude`、`codex`、`grok`、`antigravity`、`minimaxCN`、`deepseek`、`jev` |
| 显示位置 | `MacIsland.displayPresentation` | `automatic`、`notch`、`menuBar` |
| 刷新间隔 | `MacIsland.refreshInterval` | `300`、`900`、`1800` |
| 始终显示使用量 | `MacIsland.alwaysShowUsage` | 布尔值，默认 `false` |
| 低功耗模式 | `MacIsland.lowPowerMode` | 布尔值，默认 `false` |
| 已用 / 剩余 | `MacIsland.usageDisplayMode` | `used`、`remaining` |
| 图表样式 | `MacIsland.chartStyle` | `ring`、`bar`、`stepped`、`numeric`、`spark` |
| 成本样式 | `MacIsland.costStyle` | `dollar`、`multi`、`tokens`、`spark` |
| Token 统计口径 | `MacIsland.tokenCountMode` | `all`、`billable` |
| 成本货币 | `MacIsland.displayCurrency` | `USD`、`CNY`、`EUR` 等 |
| 提醒 | `MacIsland.alertsEnabled`、`MacIsland.alertWarning`、`MacIsland.alertCritical`、`MacIsland.alertNotifications` | 开关与百分比 |
| 应用语言 | `MacIsland.appLanguage` | `auto`、`en`、`zh-Hans` |

Sparkle 自己管理 `SU*` 开头的更新设置，登录时启动由 `SMAppService.mainApp` 管理。刷新、显示和服务相关的改动会立即生效；切换应用语言时会提示重启 CodexIsland。

## 从源码构建

需要 macOS 13+ 和 Xcode / Command Line Tools 自带的 Swift 工具链。

```sh
git clone https://github.com/ericjypark/codex-island
cd codex-island
./build.sh
open build/CodexIsland.app
```

项目没有 Xcode 工程，也没有 SwiftPM 包。`build.sh` 直接用 `swiftc` 编译 `Sources/**/*.swift`，分别构建 arm64 和 x86_64，用 `lipo` 合并，复制资源并写入 `Info.plist`。

测试与冒烟测试：

```sh
./scripts/run-tests.sh
./scripts/verify.sh
```

`run-tests.sh` 会编译并运行 `Tests/` 下基于裸 `swiftc` 的回归测试（凭据解析、服务数据解析与选择、定价、用量历史、预测、提醒、刘海尺寸等）。`verify.sh` 会构建应用，启动二进制 1 秒，如果仍在运行就结束进程。每个 Pull Request 的 CI 都会运行这两个脚本。

## 发布

打包 DMG：

```sh
npm install --global create-dmg
./release.sh
```

`release.sh` 会运行原生构建，把 `.app` 复制到 `dist/`，进行 ad-hoc 签名，生成 `dist/CodexIsland-X.Y.Z.dmg`；有 Sparkle EdDSA 密钥时会签名 DMG 并生成 `dist/appcast.xml`，最后输出文件大小和 SHA-256。

推送 `v*` tag 会在 `macos-15` 上触发 `.github/workflows/release.yml`：构建签名的 DMG 和 appcast，根据 Conventional Commits 生成发布说明，把两者发布到 GitHub Release，并在配置了 `HOMEBREW_TAP_TOKEN` 时把 cask 同步到 `ericjypark/homebrew-tap`。

`Casks/codexisland.rb` 是 Homebrew Cask 模板。常规发布时不要手动修改其中的版本号或 SHA，CI 会根据 tag 和新构建的 DMG 自动改写后复制到 tap。

## 目录结构

```text
.
├── Sources/
│   ├── App.swift
│   ├── Cost/                # 本地日志成本与 token 汇总
│   ├── Localization/        # 运行时本地化
│   ├── Model/               # 偏好设置、灵动岛状态、提醒
│   ├── Recovery/            # Claude 用量恢复
│   ├── Sharing/             # 用量卡片渲染与导出
│   ├── Theme/
│   ├── Update/              # Sparkle 封装
│   ├── Usage/               # 各服务接入与轮询
│   ├── Views/
│   └── Window/              # 灵动岛窗口、菜单栏图标
├── Resources/              # 图标、服务标志、本地化文案
├── Assets/                 # README 用的 logo
├── Tests/                  # 基于裸 swiftc 的回归测试
├── docs/                   # 服务接入、用量历史、性能、Sparkle
├── openspec/               # 变更提案与能力规格
├── Casks/                  # Homebrew Cask 模板
├── scripts/                # 测试、冒烟测试、Sparkle 安装
├── build.sh                # 构建通用 .app
├── release.sh              # 打包 DMG
└── VERSION
```

## 隐私

原生应用的行为：

- 没有遥测。
- 没有分析统计。
- 没有崩溃上报。
- 没有代理服务器。
- CodexIsland 不保存任何凭据。
- 模型价格每天从 GitHub 上的公开目录（[codex-island-model-catalog](https://github.com/ericjypark/codex-island-model-catalog)）获取一次。请求不带任何标识、token 或用量数据，只是一个获取静态 JSON 文件的普通 GET；请求失败时使用本地缓存。
- 凭据从各工具自己的存储中本地读取（见"首次运行"）。CodexIsland 从不写入、轮换或刷新它们。token 过期时，可能会运行一次对应的 CLI（`claude -p "ok" --model haiku`、`grok models` 或 `agy models`），由 CLI 自己刷新。
- token 只会以 `Authorization` 请求头的形式发送给对应的服务：`chatgpt.com`、`api.anthropic.com`、`cli-chat-proxy.grok.com`、`daily-cloudcode-pa.googleapis.com`、`api.minimaxi.com` 和 `api.deepseek.com`。
- 成本页读取本地日志：Claude Code 的 `~/.claude/projects/**/*.jsonl`（以及 `~/.config/claude/...` 和 `CLAUDE_CONFIG_DIR` 中的路径）、Codex 的 `~/.codex/sessions/`、OpenCode 的 `~/.local/share/opencode/`、Grok 的 `~/.grok/sessions/`，以及 Antigravity 的 `~/.gemini/antigravity-cli/conversations/`。汇总完全在本机完成，不会上传或分享任何日志内容。
- Claude 历史默认还会读取本地镜像的 Cowork 会话日志 `~/Library/Application Support/Claude/local-agent-mode-sessions/`。采集到的用量保存在 `~/Library/Application Support/dev.codexisland.CodexIsland/usage-history.sqlite3`，其中只有 token 数、模型、时间戳和不透明的记录标识，不包含提示词、回复或凭据。

各服务的网络接入代码在 [`Sources/Usage/`](Sources/Usage/)，本地日志读取代码在 [`Sources/Cost/`](Sources/Cost/)。

## 故障排查

**Claude 显示 `auth required — run claude`。**
在终端运行一次 `claude`，让 Claude Code 保存凭据。Claude 桌面应用的登录状态保存在别处，CodexIsland 不会读取。

**Claude 显示 `token expired — run claude`。**
CodexIsland 每次过期时会请 `claude` CLI 自己刷新一次，凭据一更新就会立即重新读取。如果提示一直不消失，请自己运行一次 `claude`；CodexIsland 刻意不会自行刷新 token。

**Claude 显示 `re-login: claude /login`。**
存储的 token 缺少用量接口现在要求的授权范围。运行 `claude /login` 重新获取 token；刷新旧 token 不能解决。

**Codex 显示 `no codex auth`。**
登录 Codex / ChatGPT CLI，并确认 `~/.codex/auth.json` 存在。

**Codex 显示 `auth expired — codex login`。**
运行 `codex login` 更新 `~/.codex/auth.json` 中的凭据。

**Grok 或 Antigravity 显示登录错误。**
通过官方 CLI 登录（`grok login` 或 `agy`），然后在 设置 → 服务 中点击 **刷新连接**。只在浏览器或桌面应用中登录，不会产生这里读取的 CLI 会话。

**macOS 27 上灵动岛挡住了菜单栏的"显示隐藏菜单栏项目"箭头。**
macOS 27 把这个箭头放在刘海右侧，正好在灵动岛右侧服务的下面。把 **设置 → 显示 → 显示位置** 改为 **菜单栏**：灵动岛会隐藏，箭头可以正常点击，菜单栏图标最多还能显示四个服务。

**出错后显示的是旧数据。**
这是有意为之。刷新只返回错误时，`UsageStore` 会保留上一次正确的数据，避免临时的 429 把面板变成 0%。

**为什么不能选 30 秒轮询？**
Anthropic 在账户级别对 `/api/oauth/usage` 限流非常严格，所以应用只提供 5 分钟、15 分钟和 30 分钟。

**没有刘海能用吗？**
可以。它会使用菜单栏图标，点击即可打开完整面板。如果强制使用刘海模式，可以在设置中为无刘海显示器选择紧凑宽度或更宽的刘海宽度。

**支持多显示器吗？**
支持。自动模式在没有外接显示器时使用内置刘海，连接外接显示器后切换为菜单栏图标。刘海模式下仍可以在设置中指定目标显示器。

**用量接口会失效吗？**
迟早可能。大多数服务的用量接口都没有公开文档。如果面板开始显示解析错误或 HTTP 错误，请提交 issue 并附上（去掉 token 的）响应结构。

**为什么没有 Dock 图标？**
CodexIsland 是 accessory app。在展开的灵动岛中点击齿轮打开设置，在设置中点击 退出 即可退出应用。

## 已知限制

- 未签名的构建需要移除 quarantine 或点击"仍要打开"。
- 大多数服务的用量接口没有公开文档，可能随时变化。
- 灵动岛只显示两个服务，第三、第四个只出现在菜单栏图标中。
- Sparkline 历史只包含 CodexIsland 运行期间记录的读数，各服务并不提供历史用量序列。
- 多显示器时，自动模式使用内置刘海，连接外接显示器后使用菜单栏图标；刘海模式可以把悬浮层固定到指定显示器。
- 无障碍支持还不完整：已有 VoiceOver 标签，但尚未实现高对比度样式。

## 致谢

- Peter Steinberger 的 [codexbar](https://github.com/steipete/codexbar)：Claude 凭据来源的研究。
- Rich Hickson 的 [claudecodeusage](https://github.com/RchGrav/claudecodeusage)：`/api/oauth/usage` 需要 `claude-code/2.1.121` User-Agent 的发现。
- Sindre Sorhus 的 [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern)：`SMAppService.mainApp` 的参考实现。
- [Emil Kowalski](https://animations.dev)：动画节奏与交互细节。

## 更新日志

当前的发布说明见 [GitHub Releases](https://github.com/ericjypark/codex-island/releases)，重要里程碑见 [CHANGELOG.md](CHANGELOG.md)。

## 许可证

MIT，见 [LICENSE](LICENSE)。
