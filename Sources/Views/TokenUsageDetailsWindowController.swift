import AppKit
import SwiftUI

@MainActor
final class TokenUsageDetailsWindowController: NSWindowController, NSWindowDelegate {
    static let shared = TokenUsageDetailsWindowController()

    private init() {
        let hosting = NSHostingController(rootView: TokenUsageDetailsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 620),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = hosting
        window.title = L10n.tr("Token usage details")
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(calibratedRed: 0.020, green: 0.020, blue: 0.027, alpha: 1)
        window.contentMinSize = NSSize(width: 780, height: 520)
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.center()
        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window, !window.isVisible { window.center() }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
