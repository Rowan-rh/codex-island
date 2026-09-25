import SwiftUI

struct ContentSizedPageLayout: Layout {
    let selectedPage: Int

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.indices.contains(selectedPage) else { return .zero }
        let width = proposal.width ?? 800
        // The target page owns height even while horizontal position is between pages.
        let content = subviews[selectedPage].sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: width, height: content.height)
    }

    // The default implementation merges alignment guides from every page's
    // whole subtree (including the heatmap's cells) on each layout pass.
    // Pages never align to outside guides, so skip that work.
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? { nil }

    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize,
                           subviews: Subviews, cache: inout ()) -> CGFloat? { nil }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for index in subviews.indices {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + CGFloat(index) * bounds.width, y: bounds.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: bounds.width, height: nil)
            )
        }
    }
}

/// Slides the page strip by transform instead of re-placing the pages, so a
/// swipe animates without laying out all three pages (and the heatmap) on
/// every frame.
struct PageSlideEffect: GeometryEffect {
    var position: CGFloat
    var feedbackOffset: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(position, feedbackOffset) }
        set {
            position = newValue.first
            feedbackOffset = newValue.second
        }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: -position * size.width + feedbackOffset, y: 0))
    }
}
