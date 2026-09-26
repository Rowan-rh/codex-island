import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let panelModel: IslandModel
    private let panelController: NSHostingController<MenuBarPanelView>
    private var popover: NSPopover?
    private var dismissalMonitor: Any?
    private var localDismissalMonitor: Any?
    private var appResignObserver: NSObjectProtocol?
    private var subscriptions: Set<AnyCancellable> = []
    private var lastItems: [MenuBarStatusItem] = []

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let model = IslandModel(notch: NotchInfo(width: 0, height: 32, hasNotch: true))
        panelModel = model
        panelController = NSHostingController(rootView: MenuBarPanelView(model: model))
        super.init()

        // The content is one pre-rendered image on the stock button. An
        // Auto Layout subview inside the button fought the status bar's own
        // fitting-size pass and replicant snapshots, redrawing the status
        // window every frame (~90% CPU) until relaunch.
        if let button = statusItem.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem.isVisible = false
        updateStatusView()
        appResignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.closePopover() }
        }

        ProviderVisibilityStore.shared.$selected
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusView() }
            .store(in: &subscriptions)
        UsageStore.shared.$claude
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusView() }
            .store(in: &subscriptions)
        UsageStore.shared.$codex
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusView() }
            .store(in: &subscriptions)
        ProviderConnectionStore.shared.$snapshots
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusView() }
            .store(in: &subscriptions)
        CostStore.shared.$connectedCosts
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusView() }
            .store(in: &subscriptions)
        UsageDisplayModeStore.shared.$mode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusView() }
            .store(in: &subscriptions)
        ProviderQuotaPreferences.shared.$selections
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusView() }
            .store(in: &subscriptions)
    }

    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
        if !visible { closePopover() }
    }

    @objc private func togglePopover() {
        if let popover, popover.isShown {
            closePopover()
        } else {
            let popover = self.popover ?? makePopover()
            self.popover = popover
            // The content is kept mounted between openings. Rebuilding the
            // three-page SwiftUI tree on every click made the native popover
            // animation compete with its first layout pass.
            panelModel.setState(.expanded)
            guard let button = statusItem.button else { return }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            installDismissalMonitors()
        }
    }

    private func makePopover() -> NSPopover {
        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 800, height: 320)
        popover.contentViewController = panelController
        popover.delegate = self
        return popover
    }

    private func closePopover() {
        guard let popover, popover.isShown else { return }
        popover.performClose(nil)
    }

    private func installDismissalMonitors() {
        guard dismissalMonitor == nil, localDismissalMonitor == nil else { return }

        dismissalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] _ in
            guard let self, !self.isInsidePopoverOrStatusItem() else { return }
            self.closePopover()
        }
        localDismissalMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) {
            [weak self] event in
            guard let self, !self.isInsidePopoverOrStatusItem() else { return event }
            self.closePopover()
            return event
        }
    }

    private func isInsidePopoverOrStatusItem() -> Bool {
        let location = NSEvent.mouseLocation
        if let popoverFrame = popover?.contentViewController?.view.window?.frame,
           popoverFrame.contains(location) {
            return true
        }
        if let button = statusItem.button,
           let buttonWindow = button.window {
            let buttonFrameInWindow = button.convert(button.bounds, to: nil)
            let buttonFrame = buttonWindow.convertToScreen(buttonFrameInWindow)
            return buttonFrame.contains(location)
        }
        return false
    }

    func popoverDidClose(_ notification: Notification) {
        // The mounted-but-closed panel otherwise keeps LiveDot's 30Hz
        // TimelineView ticking, which also re-snapshots the status item
        // every frame and starves the main thread.
        panelModel.setState(.compact)
        if let monitor = dismissalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localDismissalMonitor { NSEvent.removeMonitor(monitor) }
        dismissalMonitor = nil
        localDismissalMonitor = nil
    }

    deinit {
        if let observer = appResignObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let monitor = dismissalMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localDismissalMonitor { NSEvent.removeMonitor(monitor) }
    }

    private func updateStatusView() {
        let mode = UsageDisplayModeStore.shared.mode
        let items = ProviderVisibilityStore.shared.selected.map { provider in
            MenuBarStatusItem(provider: provider, value: displayValue(for: provider, mode: mode))
        }
        guard items != lastItems, let button = statusItem.button else { return }
        lastItems = items
        button.image = MenuBarStatusImage.make(items: items)
        button.setAccessibilityLabel(items.map { "\($0.provider.name) \($0.value ?? "—")" }.joined(separator: ", "))
    }

    private func displayValue(for provider: IslandProvider, mode: UsageDisplayMode) -> String? {
        if provider == .deepseek {
            return ProviderConnectionStore.shared.snapshot(provider).primaryBalance?.formattedTotal
        }
        if provider.usesLocalUsageOnly {
            let window = CostStore.shared.cost(for: provider).today
            guard window.error == nil else { return nil }
            let value = Double(window.tokens)
            if window.tokens < 1_000 { return "\(window.tokens)" }
            if window.tokens < 1_000_000 { return String(format: "%.1fk", value / 1_000) }
            if window.tokens < 1_000_000_000 { return String(format: "%.1fM", value / 1_000_000) }
            return String(format: "%.1fB", value / 1_000_000_000)
        }
        if provider == .claude || provider == .codex {
            let usage = provider == .claude ? UsageStore.shared.claude : UsageStore.shared.codex
            let window = provider == .codex ? usage.peekWindow : usage.fiveHour
            guard window.hasReading else { return nil }
            return "\(window.displayedPercentInt(mode: mode))%"
        }
        guard let limit = ProviderConnectionStore.shared.primary(provider),
              let used = limit.usedFraction else { return nil }
        let displayed = mode == .used ? used : 1 - used
        return "\(Int((max(0, min(1, displayed)) * 100).rounded()))%"
    }
}

private struct MenuBarStatusItem: Equatable {
    let provider: IslandProvider
    let value: String?
}

/// Draws the status item's icons and values into one image. The drawing
/// handler runs at display time, so label colors follow the menu bar's
/// light or dark appearance.
private enum MenuBarStatusImage {
    private static let iconSize: CGFloat = 14
    private static let iconGap: CGFloat = 3
    private static let entryGap: CGFloat = 5
    private static let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
    private static let separatorFont = NSFont.systemFont(ofSize: 11, weight: .medium)

    static func make(items: [MenuBarStatusItem]) -> NSImage {
        let entries = items.map { item in
            (icon: image(for: item.provider), tint: color(for: item.provider),
             text: NSAttributedString(string: item.value ?? "—", attributes: [.font: font]))
        }
        let separator = NSAttributedString(string: "·", attributes: [.font: separatorFont])
        var width: CGFloat = 0
        for (index, entry) in entries.enumerated() {
            if index > 0 { width += entryGap * 2 + separator.size().width }
            width += iconSize + iconGap + ceil(entry.text.size().width)
        }
        let height = NSStatusBar.system.thickness
        let size = NSSize(width: max(ceil(width), iconSize), height: height)
        return NSImage(size: size, flipped: false) { _ in
            var x: CGFloat = 0
            for (index, entry) in entries.enumerated() {
                if index > 0 {
                    x += entryGap
                    draw(separator, color: .tertiaryLabelColor, x: x, height: height)
                    x += separator.size().width + entryGap
                }
                let iconRect = NSRect(x: x, y: (height - iconSize) / 2, width: iconSize, height: iconSize)
                if let icon = entry.icon {
                    // Every mark takes its provider color. The bundled logos are
                    // black, non-template artwork, so NSImageView's tint never
                    // applied to them and they vanished on a dark menu bar.
                    icon.draw(in: iconRect)
                    entry.tint.set()
                    iconRect.fill(using: .sourceAtop)
                }
                x += iconSize + iconGap
                draw(entry.text, color: .labelColor, x: x, height: height)
                x += ceil(entry.text.size().width)
            }
            return true
        }
    }

    private static func draw(_ text: NSAttributedString, color: NSColor, x: CGFloat, height: CGFloat) {
        let colored = NSMutableAttributedString(attributedString: text)
        colored.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: colored.length))
        let size = colored.size()
        colored.draw(at: NSPoint(x: x, y: (height - size.height) / 2))
    }

    private static func image(for provider: IslandProvider) -> NSImage? {
        let resource: (String, String)? = {
            switch provider {
            case .claude: return ("claude_logo", "pdf")
            case .codex: return ("openai_logo", "pdf")
            case .grok: return ("grok_logo", "png")
            case .antigravity: return ("antigravity_logo", "png")
            case .minimaxCN: return ("minimax_logo", "svg")
            case .jev: return nil
            case .deepseek: return ("deepseek_logo", "svg")
            }
        }()
        guard let resource,
              let url = Bundle.main.url(forResource: resource.0, withExtension: resource.1) else {
            let symbol = provider == .deepseek ? "d.circle.fill"
                : provider == .jev ? "j.circle.fill" : "chart.bar.xaxis"
            return NSImage(systemSymbolName: symbol, accessibilityDescription: provider.name)
        }
        return NSImage(contentsOf: url)
    }

    private static func color(for provider: IslandProvider) -> NSColor {
        switch provider {
        case .claude: return NSColor(calibratedRed: 204 / 255, green: 120 / 255, blue: 92 / 255, alpha: 1)
        case .codex: return NSColor(calibratedRed: 90 / 255, green: 168 / 255, blue: 240 / 255, alpha: 1)
        case .grok: return .labelColor
        case .antigravity: return NSColor(calibratedRed: 182 / 255, green: 156 / 255, blue: 255 / 255, alpha: 1)
        case .minimaxCN: return NSColor(calibratedRed: 255 / 255, green: 126 / 255, blue: 70 / 255, alpha: 1)
        case .jev: return NSColor(calibratedRed: 196 / 255, green: 148 / 255, blue: 255 / 255, alpha: 1)
        case .deepseek: return NSColor(calibratedRed: 77 / 255, green: 107 / 255, blue: 254 / 255, alpha: 1)
        }
    }
}
