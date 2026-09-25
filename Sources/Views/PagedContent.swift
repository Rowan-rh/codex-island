import SwiftUI

/// Three-page horizontal carousel: live usage (page 0), cost (page 1), and
/// history overview (page 2). Each page renders at the full content width;
/// the layout slides based on
/// `ScreenPref.screen`. Horizontal movement gets its own drawer-style curve
/// so page navigation does not inherit the island shape's spring bounce.
///
/// Only the data row swipes — `PanelHeader` and `PanelFooter` are mounted
/// outside this view so they stay fixed across page changes.
///
/// First-encounter peek: on every expand until the user has swiped at
/// least once (`ScreenPref.hasSwipedScreen`), the data row slides ~28pt
/// left to reveal the cost screen's edge, then settles back. Subtle and
/// time-bounded so it stops nagging once they've discovered the gesture.
struct PagedContent: View {
    @ObservedObject var model: IslandModel
    @ObservedObject private var screenPref = ScreenPref.shared
    @State private var peekOffset: CGFloat = 0
    @State private var bumpOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0
    /// Pages built so far in this open. Only the selected page is built with
    /// the open morph; building all three (the overview heatmap especially)
    /// stalled its first frame for ~200ms, so the shape visibly lagged the text.
    @State private var mountedPages: Set<ScreenPref.Screen> = []

    var body: some View {
        ContentSizedPageLayout(selectedPage: screenPref.screen.pageIndex) {
            if isMounted(.usage) {
                UsageView()
                    .padding(.vertical, 24)
                    .accessibilityHidden(screenPref.screen != .usage)
            } else {
                Color.clear
            }
            if isMounted(.cost) {
                CostView()
                    .padding(.vertical, 24)
                    .accessibilityHidden(screenPref.screen != .cost)
            } else {
                Color.clear
            }
            if isMounted(.overview) {
                OverviewView()
                    .accessibilityHidden(screenPref.screen != .overview)
            } else {
                Color.clear
            }
        }
        .modifier(PageSlideEffect(position: CGFloat(screenPref.screen.pageIndex),
                                  feedbackOffset: peekOffset + bumpOffset + dragOffset))
        .clipped()
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 12)
                .onChanged { value in
                    let horizontal = abs(value.translation.width) > abs(value.translation.height)
                    guard horizontal else { return }
                    mountAllPages()

                    let atLeadingEdge = screenPref.screen.pageIndex == 0 && value.translation.width > 0
                    let atTrailingEdge = screenPref.screen.pageIndex == ScreenPref.Screen.allCases.count - 1
                        && value.translation.width < 0
                    dragOffset = (atLeadingEdge || atTrailingEdge)
                        ? value.translation.width * 0.24
                        : value.translation.width
                }
                .onEnded { value in
                    let horizontal = abs(value.translation.width) > abs(value.translation.height)
                    let shouldAdvance = horizontal && value.translation.width < -48
                    let shouldRewind = horizontal && value.translation.width > 48

                    withAnimation(.pageSwipe) {
                        dragOffset = 0
                        if shouldAdvance {
                            model.advanceScreen()
                        } else if shouldRewind {
                            model.rewindScreen()
                        }
                    }
                }
        )
        .onAppear {
            mountRemainingPagesAfterOpen()
            // Discoverability cue, not decorative motion — fires even
            // when @Environment(\.accessibilityReduceMotion) is on,
            // because without it reduce-motion users have no path to
            // learn the second screen exists. The motion is brief
            // (~1s total) and slow-eased.
            guard !screenPref.hasSwipedScreen,
                  screenPref.screen == .usage
            else { return }
            schedulePeek()
        }
        .onChange(of: screenPref.screen) { _ in mountAllPages() }
        .onChange(of: screenPref.hasSwipedScreen) { swiped in
            // User swiped mid-peek: collapse the peek smoothly so the
            // composite offset doesn't jump when the real screen
            // transition fires alongside it.
            if swiped, peekOffset != 0 {
                withAnimation(.pageSwipe) { peekOffset = 0 }
            }
        }
        .onChange(of: model.edgeBump) { bump in
            // Rubber-band at the carousel ends: an over-swipe nudges
            // the row 12pt toward the attempted direction and springs
            // back, so the dead-end gesture reads as "you're at the
            // edge" instead of a dropped input. The bumpOffset == 0
            // guard swallows Shift+wheel tick spam while a bump is
            // already in flight.
            guard let bump, bumpOffset == 0 else { return }
            withAnimation(.easeOut(duration: 0.10)) {
                bumpOffset = bump.direction > 0 ? -12 : 12
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.62)) {
                    bumpOffset = 0
                }
            }
        }
    }

    private func isMounted(_ page: ScreenPref.Screen) -> Bool {
        page == screenPref.screen || mountedPages.contains(page)
    }

    private func mountAllPages() {
        guard mountedPages.count < ScreenPref.Screen.allCases.count else { return }
        mountedPages = Set(ScreenPref.Screen.allCases)
    }

    /// Builds the off-screen pages once the entrance has settled, nearest
    /// first and one per step, so each build lands while nothing is moving.
    private func mountRemainingPagesAfterOpen() {
        // Record the opening page now so it stays mounted as the outgoing
        // page if the user navigates before the others are built.
        mountedPages.insert(screenPref.screen)
        let selected = screenPref.screen.pageIndex
        let remaining = ScreenPref.Screen.allCases
            .filter { $0 != screenPref.screen }
            .sorted { abs($0.pageIndex - selected) < abs($1.pageIndex - selected) }
        for (step, page) in remaining.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstMountDelay + Double(step) * 0.12) {
                mountedPages.insert(page)
            }
        }
    }

    private static let firstMountDelay = 0.5

    private func schedulePeek() {
        // Waits for the panel's openMorph + content fade-in to settle and for
        // the neighbouring page to be built, so the discoverability beat is
        // its own gesture instead of competing with the entrance.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.firstMountDelay + 0.10) {
            guard !screenPref.hasSwipedScreen else { return }
            // This is horizontal navigation affordance, so use the same
            // page curve as real swipes. It feels connected to the carousel
            // instead of to the panel's physical resize.
            withAnimation(.pageSwipe) { peekOffset = -46 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.58) {
                guard !screenPref.hasSwipedScreen else { return }
                withAnimation(.pageSwipe) { peekOffset = 0 }
            }
        }
    }
}
