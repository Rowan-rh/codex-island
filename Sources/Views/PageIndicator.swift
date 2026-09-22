import SwiftUI

/// Page indicator that mirrors the active screen. Sits in the
/// expanded panel footer between the style chip and the live-status group.
/// Each dot is tappable so regular-mouse users (no trackpad swipe, no
/// horizontal wheel) have a click-to-page affordance.
struct PageIndicator: View {
    @ObservedObject var model: IslandModel
    @ObservedObject private var screenPref = ScreenPref.shared

    var body: some View {
        HStack(spacing: 8) {
            navigationButton(direction: .backward)
            ForEach(ScreenPref.Screen.allCases, id: \.self) { screen in
                dot(for: screen)
            }
            navigationButton(direction: .forward)
        }
        .animation(.strongEaseOut, value: screenPref.screen)
    }

    private enum NavigationDirection {
        case backward
        case forward

        var symbolName: String {
            switch self {
            case .backward: return "chevron.left"
            case .forward: return "chevron.right"
            }
        }
    }

    private func navigationButton(direction: NavigationDirection) -> some View {
        let isDisabled = direction == .backward
            ? screenPref.screen.pageIndex == 0
            : screenPref.screen.pageIndex == ScreenPref.Screen.allCases.count - 1
        return Button {
            switch direction {
            case .backward: model.rewindScreen()
            case .forward: model.advanceScreen()
            }
        } label: {
            Image(systemName: direction.symbolName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(isDisabled ? 0.18 : 0.72))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(direction == .backward ? L10n.tr("Previous page") : L10n.tr("Next page"))
        .accessibilityLabel(direction == .backward ? L10n.tr("Previous page") : L10n.tr("Next page"))
    }

    private func dot(for screen: ScreenPref.Screen) -> some View {
        let isActive = screenPref.screen == screen
        return Button {
            model.showScreen(screen)
        } label: {
            Circle()
                .fill(.white.opacity(isActive ? 0.78 : 0.22))
                .frame(width: 5, height: 5)
                // Visual stays 5pt; hit area expands ~6pt outward so the dot
                // is reachable without pixel-precise aim.
                .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .help(L10n.tr("Switch to %@ (⌘%d)", screen.pageLabel, screen.pageIndex + 1))
        .accessibilityLabel(accessibilityLabel(for: screen))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func accessibilityLabel(for screen: ScreenPref.Screen) -> String {
        L10n.tr("%@ page, %d of %d", screen.pageLabel, screen.pageIndex + 1, ScreenPref.Screen.allCases.count)
    }
}
