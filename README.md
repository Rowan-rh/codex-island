# CodexIsland

[English](README.md) | [简体中文](README.zh-CN.md)

<p align="center">
  <img src="Assets/codexisland-logo.png" width="160" alt="CodexIsland logo">
</p>

<p align="center">
  <a href="https://hits.sh/github.com/ericjypark/codex-island/">
    <img alt="README visitors" src="https://hits.sh/github.com/ericjypark/codex-island.svg?label=visitors&color=007ec6&labelColor=555555">
  </a>
</p>

> Your AI usage limits, living in your notch.

CodexIsland is a native macOS overlay that turns the MacBook notch into a
Dynamic-Island-style live activity for AI usage limits and account status. It
sits quietly over the notch, peeks on hover, and expands on click to show
provider limits or wallet balance alongside chart controls, local-log cost
estimates, and a year-at-a-glance usage history. On a Mac without a notch, or
whenever you prefer, it lives in the menu bar instead.

https://github.com/user-attachments/assets/195beeff-0f70-4d6b-8f3d-9f31d9c0b989


The app is free, open source, unsigned, and local-first. It reads credentials
already written by the official CLIs and desktop apps you use, then calls only
the providers' own usage endpoints.

## Supported providers

| Provider | What the island shows | Where it comes from |
| --- | --- | --- |
| Claude | 5-hour and weekly limits, plan | Claude Code credentials (read-only) |
| Codex | 5-hour and weekly limits (or weekly only), reset credits | `~/.codex/auth.json` |
| Grok | Subscription credit usage for the billing period | Grok CLI session in `~/.grok/auth.json` |
| Google Antigravity | Quota windows for a selectable model group | `agy` CLI Keychain entry |
| MiniMax CN | Token Plan 5-hour and weekly windows | `mmx` CLI config or `MINIMAX_CN_API_KEY` |
| DeepSeek | API wallet balance | `DEEPSEEK_API_KEY` or DeepSeek Harness |
| Jev | Today's and this month's local token usage | Local OpenCode records only |

Pick any two for the island's left and right slots; the menu bar icon can show
up to four. Every provider also feeds the local Cost and Overview screens when
its CLI leaves usage logs on your Mac. Details for each adapter live in
[docs/PROVIDERS.md](docs/PROVIDERS.md).

## What it does

### Island and menu bar

- **Notch-native overlay.** The compact state is a black pill aligned to the
  physical notch, drawn with continuous (squircle) corners that match the
  hardware.
- **Hover to peek.** The silhouette widens just enough to show each visible
  provider's current-window percentage and reset countdown, or keep those
  headlines visible at rest with **Always show usage**.
- **Click to expand.** The full panel opens with provider columns, chart
  controls, and a sync status you can click to refetch immediately.
- **Display placement.** Choose **Automatic**, **Notch**, or **Menu Bar**.
  Automatic uses the built-in notch and switches to a menu bar icon when an
  external display is connected. Menu Bar mode hides the island entirely; the
  icon shows each provider's mark and percentage, and clicking it opens the
  same full panel.
- **Up to four providers in the menu bar.** Beyond the two island slots, add
  up to two more under **Settings → Providers → More in the menu bar**.
- **Display selection.** Auto-pick a notched display or pin the island to a
  specific connected display. Non-notched displays offer compact and
  notch-style widths.
- **Click-through outside the island.** The window ignores mouse events outside
  the visible silhouette so the menu bar and apps underneath still work.

### Usage

- **Three swipeable screens.** Swipe, use the indicator dots, press ←/→, or
  press ⌘1–⌘3 to move between **Usage**, **Cost**, and **Overview**.
- **Five chart styles.** Ring, Bar, Stepped, Numeric, and Sparkline. Pick the
  default in Settings or Command-click the expanded panel to cycle. Sparkline
  uses real readings recorded by CodexIsland during successful refreshes.
- **Used or remaining quota.** Display provider windows as usage consumed or
  quota remaining.
- **Run-out forecast.** When the recent pace would use up a window before it
  resets, its usage tile shows roughly when that happens. The pace comes from
  readings the app already records, so the forecast adds no polling and stays
  hidden until there is at least 15 minutes of history in the current cycle.
- **Codex reset credits.** When reset credits are available, the Usage footer
  shows their count and expiration details.
- **Actionable empty states.** A provider with no readings shows "No active
  subscription" or "Usage unavailable" with a link to its settings, instead of
  a fake 0%.

### Cost and history

- **Local cost estimates.** Cost estimates today and month-to-date spend and
  token throughput from local Claude Code, Codex CLI, OpenCode, Grok CLI, and
  Antigravity CLI data, shown as USD, API value, tokens, or a trend.
  Figures can be displayed in USD, CNY, EUR, GBP, JPY, KRW, CAD, AUD, or CHF.
- **Year at a glance.** Overview renders the current year's activity as a
  contribution-style calendar using logs from every supported provider,
  regardless of which providers are selected for the island. Click a provider
  in the legend to filter its history; click it again to show all providers.
- **A usage card worth sharing.** Open **Overview → Share usage** or
  **Settings → General → Usage card**. Put your estimated API value in USD
  front and center, with a flowing cumulative chart and provider amounts, or
  spotlight your token count. Choose a dark **Solid**, **Aurora**, **Orbit**,
  or **Grid** background; pick **Last 7 days** (default), **Last 30 days**,
  **Last 3 months**, **This year**, or **All time**; choose a feed / square /
  story format and an optional signature; then share through the macOS share
  menu, save a 1080-pixel-wide PNG, or copy the image and caption. After an app
  update, the card opens once when your weekly usage is ready. Figures follow
  your local calendar and include cache usage; API value is an estimate, not
  your subscription bill. Everything is rendered on your Mac.
- **Usage history that stays yours.** CodexIsland saves captured token counts
  in its own local database, so provider log cleanup no longer erases history,
  and repeated scans update the same calls instead of counting them again. See
  [usage-history storage](docs/USAGE-HISTORY.md). **Settings → General →
  Recover Claude usage…** previews verified counts from surviving logs,
  backups, and old daily snapshots before importing them; a
  [terminal script](docs/USAGE-HISTORY.md#recover-your-claude-usage) is also
  included.
- **Configurable token counting.** The TOKENS hero can sum every token type
  that crossed the wire (cache included, ccusage parity) or input + output
  only — the latter matches Anthropic's claude.ai stats panel.

### Alerts

- **Approaching-limit alerts.** Optional warning and critical thresholds tint
  the island's glow amber or red and pulse the peek pill once when a visible
  window crosses them.
- **System notifications.** Optional macOS notifications when a window first
  crosses a threshold (with the forecast run-out time) and when a window that
  reached warning resets. Turn them on under **Settings → General → Alerts**.
- **Cobalt glow + Low Power Mode.** A soft glow around the island signals an
  in-flight refresh and rests after a minute of inactivity. Low Power Mode
  hides the steady-state glow so it only appears on refresh, hover, or alerts.

### App

- **English and Simplified Chinese.** Follow the macOS language automatically
  or choose a language in Settings.
- **Settings without a Dock icon.** The gear in the expanded panel (or ⌘,)
  opens a custom settings window with General, Display, and Providers tabs.
- **Configurable safe polling.** Choose 5m, 15m, or 30m. The app does not offer
  sub-5-minute polling because Anthropic rate-limits the usage endpoint
  aggressively.
- **Auto-updates via Sparkle.** The app checks the appcast attached to the
  latest GitHub Release in the background, then prompts before installing.
  Updates are signed with an EdDSA key — verifiable without involving Apple's
  signing infrastructure. Toggle off automatic checks in Settings if you'd
  rather pin a version.
- **Universal binary.** `build.sh` compiles arm64 and x86_64 slices and merges
  them with `lipo`, targeting macOS 13+.
- **Native app privacy.** No app telemetry, no crash reporting, no third-party
  app analytics, and no proxy service.

## Install

### Homebrew

```sh
brew install --cask ericjypark/tap/codexisland
```

The first invocation auto-taps `ericjypark/homebrew-tap`. The cask strips the
Gatekeeper quarantine attribute automatically (CodexIsland is unsigned by
Apple — Sparkle handles update verification independently).

### Direct download

Download the current `CodexIsland-X.Y.Z.dmg` from the
[latest release](https://github.com/ericjypark/codex-island/releases/latest),
drag the app to `/Applications`, then run:

```sh
xattr -dr com.apple.quarantine /Applications/CodexIsland.app
```

<details>
<summary>Why is the dequarantine command necessary?</summary>

CodexIsland is unsigned because Apple charges $99/year for a Developer ID
certificate, and this is a free open-source project. The command removes the
macOS Gatekeeper quarantine attribute that triggers the "cannot be opened
because Apple cannot check it for malicious software" warning. The source code
is in this repository for audit.

If a sponsored Apple Developer ID becomes available via
[GitHub Sponsors](https://github.com/sponsors/ericjypark), signed builds can
follow.
</details>

<details>
<summary>I do not want to use Terminal. What do I do?</summary>

1. Drag `CodexIsland.app` to `/Applications`.
2. Try to open it. macOS will block it because the build is unsigned.
3. Open **System Settings -> Privacy & Security**.
4. Scroll to the bottom and find the blocked CodexIsland message.
5. Click **Open Anyway**, then re-launch the app.
</details>

## First run

CodexIsland does not ask for passwords or API keys. It reads the auth state
already created by the command-line tools or desktop apps you use, and never
writes, rotates, or refreshes another tool's credentials itself.

**Claude**

- Run `claude` once so Claude Code stores its credentials.
- CodexIsland checks `CLAUDE_CODE_OAUTH_TOKEN`, then the macOS Keychain items
  Claude Code writes (`Claude Code-credentials`, plus per-`CLAUDE_CONFIG_DIR`
  variants), then `$CLAUDE_CONFIG_DIR/.credentials.json` as a fallback.
- Credential access is strictly read-only. When the stored token has expired
  and nothing is refreshing it (for example, you only use the Claude desktop
  app), CodexIsland runs one `claude -p "ok" --model haiku` per expiry so the
  CLI refreshes its own login. Run `claude /login` when the endpoint requires a
  newly scoped token.
- If no credentials are found, the panel shows `auth required — run claude`.

**Codex**

- Sign in to the Codex / ChatGPT CLI first.
- CodexIsland reads `~/.codex/auth.json`.
- If the file or access token is missing, the panel shows `no codex auth`.

**Grok**

- Sign in with the official Grok CLI (`grok login`) using your Grok
  subscription. A grok.com browser login alone is not enough.
- CodexIsland reads `$GROK_HOME/auth.json` (default `~/.grok/auth.json`). On
  expiry it runs `grok models` once so the CLI renews its own session.

**Google Antigravity**

- Sign in with the official `agy` CLI; the desktop app is not required.
- CodexIsland reads the CLI's Keychain entry (`gemini` / `antigravity`). On
  expiry it runs `agy models` once so the CLI renews its own session.
- Settings can choose which model group and metrics to show.

**MiniMax CN**

- Sign in with the official MiniMax CLI
  (`mmx auth login --recommend --region=cn`), or provide `MINIMAX_CN_API_KEY`.
- CodexIsland reads the CLI's `~/.mmx/config.json` (or `MMX_CONFIG_DIR`). Use a
  MiniMax CN Subscription Key, not a regular pay-as-you-go API key.

**DeepSeek**

- Provide `DEEPSEEK_API_KEY`, or save it through DeepSeek Harness
  (`$DSH_HOME/.credentials.yaml`, normally `~/.dsh/.credentials.yaml`).
- The app shows wallet balance only; it does not use private dashboard APIs or
  read browser sessions.

**Jev**

- CodexIsland reads local OpenCode session records whose provider is Jev or
  TypeSafe and shows today's and this month's token usage.
- Jev has no account-quota surface in the app, and its credentials are never
  read.

The first fetch starts at app launch so the panel usually has values ready by
the first peek. Opening Settings also triggers a fresh fetch.

## Using the app

- Hover the notch to peek at the current usage; move away to collapse it.
- Click the island (or the menu bar icon) to expand the full panel.
- Swipe horizontally, click the indicator dots, press ←/→, or press ⌘1–⌘3 to
  move between **Usage**, **Cost**, and **Overview**.
- Command-click the expanded panel to cycle chart styles on the active screen
  (Usage cycles Ring/Bar/Stepped/Numeric/Sparkline; Cost cycles
  USD/VALUE/TOKENS/TREND; Overview has one calendar view).
- Click `synced Xs ago` in the panel header to refetch immediately.
- Click the gear in the lower-left corner of the expanded panel, or press ⌘,,
  to open Settings.
- Press ⌘Q while the pointer is over the island to quit. You can also quit
  from Settings.

Choosing providers only changes what is displayed. The app keeps the latest
values in memory, so bringing a provider back does not start from zero.

## Settings

Settings is a custom `NSWindow`, not the system Settings scene. The app still
runs as an accessory app with no Dock icon. In Menu Bar mode it exposes a
status-bar icon instead of the notch overlay.

- **General:** Launch at Login, 5m/15m/30m refresh interval, app language,
  Always show usage, Low Power Mode, usage card, Claude usage recovery,
  approaching-limit alerts and system notifications, and Sparkle update
  controls.
- **Display:** Automatic / Notch / Menu Bar placement, used or remaining
  percentages, Usage and Cost chart styles, target display, and island width
  on non-notched displays.
- **Providers:** the left and right island providers, up to two more for the
  menu bar, each provider's connection status and sign-in actions, token
  counting mode, cost currency, and a manual refresh for local cost data.

Cost conversion uses a cached daily reference rate; model prices and cost
calculations remain in USD. Like model pricing, exchange rates load from cache
at startup, are checked every six hours, and are fetched when at least 24 hours
old. Offline, the last valid table is kept (or USD is shown until one exists).

Main preferences live in `UserDefaults` under `MacIsland.*` keys:

| Setting | Key | Values |
| --- | --- | --- |
| Providers (ordered) | `MacIsland.selectedProviders` | Up to four of `claude`, `codex`, `grok`, `antigravity`, `minimaxCN`, `deepseek`, `jev` |
| Display placement | `MacIsland.displayPresentation` | `automatic`, `notch`, `menuBar` |
| Refresh interval | `MacIsland.refreshInterval` | `300`, `900`, `1800` |
| Always show usage | `MacIsland.alwaysShowUsage` | Boolean, default `false` |
| Low Power Mode | `MacIsland.lowPowerMode` | Boolean, default `false` |
| Used / remaining | `MacIsland.usageDisplayMode` | `used`, `remaining` |
| Chart style | `MacIsland.chartStyle` | `ring`, `bar`, `stepped`, `numeric`, `spark` |
| Cost style | `MacIsland.costStyle` | `dollar`, `multi`, `tokens`, `spark` |
| Token counting | `MacIsland.tokenCountMode` | `all`, `billable` |
| Cost currency | `MacIsland.displayCurrency` | `USD`, `CNY`, `EUR`, … |
| Alerts | `MacIsland.alertsEnabled`, `MacIsland.alertWarning`, `MacIsland.alertCritical`, `MacIsland.alertNotifications` | Toggle and percentages |
| App language | `MacIsland.appLanguage` | `auto`, `en`, `zh-Hans` |

Sparkle manages its own `SU*` update keys, and Launch at Login uses
`SMAppService.mainApp`. Refresh, display, and provider changes apply live;
changing the app language offers to restart CodexIsland.

## Build from source

Requires macOS 13+ and a Swift toolchain from Xcode / Command Line Tools.

```sh
git clone https://github.com/ericjypark/codex-island
cd codex-island
./build.sh
open build/CodexIsland.app
```

There is no Xcode project and no SwiftPM package. `build.sh` runs `swiftc` over
`Sources/**/*.swift`, compiles arm64 and x86_64 slices, merges them with
`lipo`, copies bundled resources, and writes `Info.plist`.

Smoke test the native app:

```sh
./scripts/run-tests.sh
./scripts/verify.sh
```

`run-tests.sh` compiles and runs the bare-`swiftc` regression harnesses in
`Tests/` (credential resolution, provider parsing and selection, pricing,
usage history, forecasts, alerts, notch geometry, and more). `verify.sh`
builds the app, launches the binary for one second, then kills it if it is
still alive. The same two scripts run in CI on every pull request.

## Release

Package a DMG:

```sh
npm install --global create-dmg
./release.sh
```

`release.sh` runs the native build, copies the `.app` to `dist/`, applies ad-hoc
codesigning, creates `dist/CodexIsland-X.Y.Z.dmg`, signs it with Sparkle's
EdDSA key when available, generates `dist/appcast.xml`, and prints the file size
and SHA-256.

Pushing a `v*` tag triggers `.github/workflows/release.yml` on `macos-15`,
builds the signed DMG and appcast, generates release notes from Conventional
Commits, publishes both artifacts in a GitHub Release, and mirrors the cask to
`ericjypark/homebrew-tap` when `HOMEBREW_TAP_TOKEN` is configured.

`Casks/codexisland.rb` is the Homebrew Cask template. Do not manually bump its
version or SHA for normal releases; CI copies it to the tap and rewrites those
fields from the tag and freshly built DMG.

## Repository layout

```text
.
├── Sources/
│   ├── App.swift
│   ├── Cost/                # Local-log cost + token aggregation
│   ├── Localization/        # Runtime localization helper
│   ├── Model/               # Preferences, island state, alerts
│   ├── Recovery/            # Claude usage recovery
│   ├── Sharing/             # Usage card rendering and export
│   ├── Theme/
│   ├── Update/              # Sparkle wrapper
│   ├── Usage/               # Provider adapters and polling
│   ├── Views/
│   └── Window/              # Island window, menu bar item
├── Resources/              # Icons, provider marks, localized strings
├── Assets/                 # README logo asset
├── Tests/                  # Bare-swiftc regression harnesses
├── docs/                   # Providers, usage history, performance, Sparkle
├── openspec/               # Change proposals and capability specs
├── Casks/                  # Homebrew Cask template
├── scripts/                # Tests, native smoke test, Sparkle setup
├── build.sh                # Universal .app build
├── release.sh              # DMG packaging
└── VERSION
```

## Privacy

Native app behavior:

- No app telemetry.
- No app analytics.
- No crash reporting.
- No proxy server.
- No credentials are stored by CodexIsland.
- Model prices are fetched once a day from a public, GitHub-hosted catalog
  ([codex-island-model-catalog](https://github.com/ericjypark/codex-island-model-catalog)).
  The request carries no identifier, no token, and no usage data — it is a
  plain GET for a static JSON file, and the app works from a local cache when
  it fails.
- Credentials are read locally from each tool's own store (see First run).
  CodexIsland never writes, rotates, or refreshes them. When a token expires,
  it may run the owning CLI once (`claude -p "ok" --model haiku`,
  `grok models`, or `agy models`) so that CLI refreshes itself.
- Tokens leave the machine only as `Authorization` headers to their own
  providers: `chatgpt.com`, `api.anthropic.com`, `cli-chat-proxy.grok.com`,
  `daily-cloudcode-pa.googleapis.com`, `api.minimaxi.com`, and
  `api.deepseek.com`.
- The Cost screen reads local Claude Code session logs from
  `~/.claude/projects/**/*.jsonl` (and `~/.config/claude/...`, plus any path
  in `CLAUDE_CONFIG_DIR`), Codex session logs from `~/.codex/sessions/`,
  OpenCode data from `~/.local/share/opencode/`, Grok sessions from
  `~/.grok/sessions/`, and Antigravity conversations from
  `~/.gemini/antigravity-cli/conversations/`. Aggregation happens entirely
  on-device — no log content is uploaded or shared anywhere.
- Default Claude history discovery also includes locally mirrored Cowork
  session logs in `~/Library/Application Support/Claude/local-agent-mode-sessions/`.
  Captured usage is retained in
  `~/Library/Application Support/dev.codexisland.CodexIsland/usage-history.sqlite3`.
  The database contains token counts, models, timestamps, and opaque record
  identifiers; it does not contain prompts, responses, or credentials.

The visitor badge at the top of this README is an external `hits.sh` image that
counts badge requests. It is not bundled with or contacted by the native app.

Provider network adapters live in [`Sources/Usage/`](Sources/Usage/). The local
log readers live in [`Sources/Cost/`](Sources/Cost/).

## Troubleshooting

**Claude shows `auth required — run claude`.**
Run `claude` once in Terminal so Claude Code stores its credentials. The
Claude desktop app keeps its own login elsewhere, which CodexIsland does not
read.

**Claude shows `token expired — run claude`.**
CodexIsland asks the `claude` CLI to refresh itself once per expiry and picks up
the new token as soon as the credential store changes. If the message stays,
run `claude` yourself; CodexIsland intentionally never refreshes the token.

**Claude shows `re-login: claude /login`.**
The stored token is missing a scope now required by the usage endpoint. Run
`claude /login` to mint a newly scoped token; refreshing the old token is not
enough.

**Codex shows `no codex auth`.**
Sign in to Codex / ChatGPT CLI and confirm `~/.codex/auth.json` exists.

**Codex shows `auth expired — codex login`.**
Run `codex login` to refresh the credentials in `~/.codex/auth.json`.

**Grok or Antigravity shows a sign-in error.**
Sign in with the official CLI (`grok login` or `agy`), then choose **Refresh
connection** in Settings → Providers. A browser or desktop-app login alone does
not create the CLI session these adapters read.

**On macOS 27 the island covers the menu bar's "show hidden items" arrow.**
macOS 27 places that arrow just right of the notch, under the island's right
provider. Switch **Settings → Display → Display location** to **Menu Bar**: the
island disappears, the arrow is reachable again, and the menu bar icon can show
up to four providers.

**The app shows stale values after an error.**
That is intentional. `UsageStore` keeps the previous good values when a refresh
returns only errors, so a temporary 429 does not turn the panel into 0%.

**Why can I not choose 30-second polling?**
Anthropic rate-limits `/api/oauth/usage` aggressively at the account level. The
app exposes 5m, 15m, and 30m only.

**Does it work without a notch?**
Yes. It uses a menu-bar icon; click the icon to open the full panel. If you
force the Notch placement, Settings can switch between compact and wider
notch-style spacing on non-notched displays.

**Does it support multiple monitors?**
Yes. Automatic placement uses the built-in Mac notch without an external
display and switches to a menu-bar icon when one is connected. The target
display can still be pinned in Settings for the notch overlay.

**Will the usage endpoints break?**
Probably at some point. Most provider usage endpoints are undocumented. If the panel
starts showing parse errors or HTTP errors, open an issue with the response
shape and redact tokens.

**Why is there no Dock icon?**
CodexIsland is an accessory app. Use the gear in the expanded island to open
Settings, and use Settings -> Quit to exit.

## Known limits

- Unsigned builds require dequarantine / Open Anyway.
- Most provider usage endpoints are undocumented and can change without notice.
- The island shows two providers; a third and fourth appear only in the menu
  bar icon.
- Sparkline history contains only readings CodexIsland records while it is
  running; providers do not expose historical usage series.
- Multi-monitor setups use the built-in notch automatically and a menu-bar
  icon when an external display is connected; Notch mode can pin one overlay
  to a selected display.
- Accessibility is partial: VoiceOver labels exist, but a high-contrast variant
  is not implemented yet.

## Acknowledgements

- [codexbar](https://github.com/steipete/codexbar) by Peter Steinberger -
  auth-source archaeology for Claude credential resolution.
- [claudecodeusage](https://github.com/RchGrav/claudecodeusage) by Rich Hickson
  - the `claude-code/2.1.121` User-Agent requirement on `/api/oauth/usage`.
- [LaunchAtLogin-Modern](https://github.com/sindresorhus/LaunchAtLogin-Modern)
  by Sindre Sorhus - reference shape for `SMAppService.mainApp`.
- [Emil Kowalski](https://animations.dev) - animation timing and interaction
  discipline.

## Changelog

See [GitHub Releases](https://github.com/ericjypark/codex-island/releases) for
current release notes and [CHANGELOG.md](CHANGELOG.md) for curated milestone
notes.

## License

MIT - see [LICENSE](LICENSE).
