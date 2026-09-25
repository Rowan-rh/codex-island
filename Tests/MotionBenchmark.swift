import AppKit
import SwiftUI

// Measures main-loop gaps while the open morph and page swipes are animating.
@main
@MainActor
struct MotionBenchmark {
    static func stats(_ label: String, _ values: [Double]) {
        let v = values.sorted()
        guard !v.isEmpty else { return }
        func p(_ q: Double) -> Double { v[Int(Double(v.count - 1) * q)] }
        print(String(format: "%@ samples=%d p50=%.1fms p95=%.1fms max=%.1fms over16.7ms=%.0f%%", label, v.count,
                     p(0.5), p(0.95), v.last ?? 0, Double(v.filter { $0 > 16.7 }.count) / Double(v.count) * 100))
    }

    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        UsageStore.shared.refresh()
        CostStore.shared.refresh()
        ScreenPref.shared.screen = .usage
        ScreenPref.shared.hasSwipedScreen = true
        let model = IslandModel(notch: NotchInfo(width: 180, height: 32, hasNotch: true))
        let window = NSWindow(contentRect: NSRect(x: 100, y: 200, width: 900, height: 420),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = NSHostingView(rootView: IslandRootView(model: model))
        window.orderFrontRegardless()
        var previous = ProcessInfo.processInfo.systemUptime
        let start = previous
        var phaseStart = start
        var morph: [Double] = [], swipe: [Double] = []
        var step = -1
        var expanded = false
        var inSwipe = false
        let timer = Timer(timeInterval: 1.0 / 240, repeats: true) { _ in
            MainActor.assumeIsolated {
                let now = ProcessInfo.processInfo.systemUptime
                let gap = (now - previous) * 1000
                previous = now
                let t = now - start
                guard t > 2 else { return }
                // 2–14s: expand/collapse every 1.2s; record 60–500ms after expand (first frame excluded).
                if t < 14 {
                    if expanded, now - phaseStart > 0.06, now - phaseStart < 0.5 { morph.append(gap) }
                    let s = Int((t - 2) / 1.2)
                    if s != step {
                        step = s
                        expanded.toggle()
                        phaseStart = now
                        withAnimation(expanded ? .openMorph : .closeMorph) {
                            model.setState(expanded ? .expanded : .compact)
                        }
                    }
                    return
                }
                // 14–15s: open and let every page build.
                if t < 15 {
                    if model.state != .expanded { withAnimation(.openMorph) { model.setState(.expanded) } }
                    step = -1
                    return
                }
                // 15–27s: swipe every 0.8s; record the 0.36s swipe window.
                if inSwipe, now - phaseStart < 0.36 { swipe.append(gap) }
                let s = Int((t - 15) / 0.8)
                if s != step {
                    step = s
                    inSwipe = true
                    phaseStart = now
                    let pages = ScreenPref.Screen.allCases
                    model.showScreen(pages[(s + 1) % pages.count])
                }
                if t >= 27 {
                    stats("open morph", morph)
                    stats("page swipe", swipe)
                    exit(0)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        app.run()
    }
}
