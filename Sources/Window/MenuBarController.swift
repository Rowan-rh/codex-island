import AppKit
import SwiftUI
import Combine

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let statusItem: NSStatusItem
    private let statusView: MenuBarStatusView
    private let panelModel: IslandModel
    private let panelController: NSHostingController<MenuBarPanelView>
    private var popover: NSPopover?
    private var dismissalMonitor: Any?
    private var localDismissalMonitor: Any?
    private var appResignObserver: NSObjectProtocol?
    private var subscriptions: Set<AnyCancellable> = []
    private var lastItems: [MenuBarStatusItem] = []

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusView = MenuBarStatusView()
        let model = IslandModel(notch: NotchInfo(width: 0, height: 32, hasNotch: true))
        model.setState(.expanded)
        panelModel = model
        panelController = NSHostingController(rootView: MenuBarPanelView(model: model))
        super.init()

        statusView.onClick = { [weak self] in self?.togglePopover() }
        if let button = statusItem.button {
            button.addSubview(statusView)
            NSLayoutConstraint.activate([
                statusView.leadingAnchor.constraint(equalTo: button.leadingAnchor),
                statusView.trailingAnchor.constraint(equalTo: button.trailingAnchor),
                statusView.topAnchor.constraint(equalTo: button.topAnchor),
                statusView.bottomAnchor.constraint(equalTo: button.bottomAnchor)
            ])
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
            popover.show(relativeTo: statusView.bounds, of: statusView, preferredEdge: .minY)
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
        guard items != lastItems else { return }
        lastItems = items
        statusView.update(items: items)
        statusItem.length = max(NSStatusItem.squareLength, statusView.fittingSize.width)
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

private final class MenuBarStatusView: NSView {
    var onClick: (() -> Void)?
    private let stack = NSStackView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 5
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var intrinsicContentSize: NSSize { stack.fittingSize }

    override func mouseDown(with event: NSEvent) { onClick?() }
    override func rightMouseDown(with event: NSEvent) { onClick?() }

    func update(items: [MenuBarStatusItem]) {
        stack.arrangedSubviews.forEach { view in
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }
        for (index, item) in items.enumerated() {
            if index > 0 {
                let separator = NSTextField(labelWithString: "·")
                separator.textColor = .tertiaryLabelColor
                separator.font = NSFont.systemFont(ofSize: 11, weight: .medium)
                stack.addArrangedSubview(separator)
            }
            stack.addArrangedSubview(entry(item))
        }
        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    private func entry(_ item: MenuBarStatusItem) -> NSView {
        let row = NSStackView()
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 3

        let icon = NSImageView()
        icon.image = Self.image(for: item.provider)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.contentTintColor = Self.color(for: item.provider)
        icon.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            icon.widthAnchor.constraint(equalToConstant: 14),
            icon.heightAnchor.constraint(equalToConstant: 14)
        ])

        let value = NSTextField(labelWithString: item.value ?? "—")
        value.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        value.textColor = .labelColor
        value.toolTip = item.provider.name
        row.addArrangedSubview(icon)
        row.addArrangedSubview(value)
        return row
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
