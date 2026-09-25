import SwiftUI

enum WeeklyCardFormat: String, CaseIterable, Identifiable {
    case feed, square, story
    var id: String { rawValue }
    var title: String {
        switch self {
        case .feed: return L10n.tr("Feed · 4:5")
        case .square: return L10n.tr("Square · 1:1")
        case .story: return L10n.tr("Story · 9:16")
        }
    }
    var size: CGSize {
        switch self {
        case .feed: return CGSize(width: 540, height: 675)
        case .square: return CGSize(width: 540, height: 540)
        case .story: return CGSize(width: 540, height: 960)
        }
    }
    var pixelLabel: String { "1080 × \(Int(size.height * 2)) PNG" }
}

enum WeeklyCardBackdropStyle: String, CaseIterable, Identifiable {
    case solid, aurora, orbit, grid

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: return L10n.tr("Solid")
        case .aurora: return L10n.tr("Aurora")
        case .orbit: return L10n.tr("Orbit")
        case .grid: return L10n.tr("Grid")
        }
    }
}

struct WeeklyCardBackdrop: View {
    let style: WeeklyCardBackdropStyle

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            ZStack {
                baseColor
                switch style {
                case .solid:
                    EmptyView()
                case .aurora:
                    LinearGradient(colors: [
                        Color(red: 0.035, green: 0.060, blue: 0.085),
                        Color(red: 0.025, green: 0.042, blue: 0.060),
                        Color(red: 0.060, green: 0.045, blue: 0.075)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    glow(Color(red: 0.16, green: 0.64, blue: 0.68), width: size.width * 1.25,
                         height: size.height * 0.62)
                        .position(x: size.width * 0.91, y: size.height * 0.16)
                    glow(Color(red: 0.39, green: 0.31, blue: 0.76), width: size.width * 1.15,
                         height: size.height * 0.56)
                        .position(x: size.width * 0.80, y: size.height * 0.88)
                    glow(Color(red: 0.83, green: 0.35, blue: 0.28), width: size.width * 0.70,
                         height: size.height * 0.42)
                        .position(x: size.width * 0.09, y: size.height * 1.04)
                case .orbit:
                    LinearGradient(colors: [
                        Color(red: 0.040, green: 0.069, blue: 0.103),
                        Color(red: 0.025, green: 0.040, blue: 0.056)
                    ], startPoint: .topTrailing, endPoint: .bottomLeading)
                    Canvas { context, canvasSize in
                        let center = CGPoint(x: canvasSize.width * 0.88, y: canvasSize.height * 0.42)
                        for index in 0..<8 {
                            let radius = canvasSize.width * (0.20 + CGFloat(index) * 0.095)
                            let bounds = CGRect(x: center.x - radius, y: center.y - radius,
                                                width: radius * 2, height: radius * 2)
                            context.stroke(Path(ellipseIn: bounds),
                                           with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.12 : 0.07)),
                                           lineWidth: index.isMultiple(of: 2) ? 0.8 : 0.5)
                        }
                        let dot = CGRect(x: center.x - canvasSize.width * 0.26, y: center.y - canvasSize.width * 0.10,
                                         width: 5, height: 5)
                        context.fill(Path(ellipseIn: dot), with: .color(Color(red: 0.52, green: 0.80, blue: 0.98)))
                    }
                case .grid:
                    LinearGradient(colors: [
                        Color(red: 0.034, green: 0.071, blue: 0.072),
                        Color(red: 0.026, green: 0.040, blue: 0.052),
                        Color(red: 0.043, green: 0.052, blue: 0.064)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Canvas { context, canvasSize in
                        let spacing: CGFloat = 36
                        let columns = Int(ceil(canvasSize.width / spacing))
                        let rows = Int(ceil(canvasSize.height / spacing))
                        for column in 0..<columns {
                            let x = CGFloat(column + 1) * spacing
                            var line = Path()
                            line.move(to: CGPoint(x: x, y: 0))
                            line.addLine(to: CGPoint(x: x, y: canvasSize.height))
                            context.stroke(line, with: .color(.white.opacity((column + 1).isMultiple(of: 4) ? 0.11 : 0.045)), lineWidth: 0.5)
                        }
                        for row in 0..<rows {
                            let y = CGFloat(row + 1) * spacing
                            var line = Path()
                            line.move(to: CGPoint(x: 0, y: y))
                            line.addLine(to: CGPoint(x: canvasSize.width, y: y))
                            context.stroke(line, with: .color(.white.opacity((row + 1).isMultiple(of: 4) ? 0.11 : 0.045)), lineWidth: 0.5)
                        }
                    }
                    glow(Color(red: 0.13, green: 0.47, blue: 0.39), width: size.width * 0.85,
                         height: size.height * 0.48)
                        .position(x: size.width * 0.98, y: size.height * 0.98)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipped()
        }
    }

    private var baseColor: Color {
        switch style {
        case .solid: return WeeklyCardTheme.midnight.background
        case .aurora: return Color(red: 0.025, green: 0.040, blue: 0.057)
        case .orbit: return Color(red: 0.025, green: 0.040, blue: 0.056)
        case .grid: return Color(red: 0.026, green: 0.040, blue: 0.052)
        }
    }

    private func glow(_ color: Color, width: CGFloat, height: CGFloat) -> some View {
        Ellipse()
            .fill(RadialGradient(colors: [color.opacity(0.30), color.opacity(0.08), .clear],
                                 center: .center, startRadius: 0, endRadius: width * 0.5))
            .frame(width: width, height: height)
    }
}

struct WeeklyCardTheme {
    static let midnight = WeeklyCardTheme()

    let background = Color(red: 0.035, green: 0.044, blue: 0.052)
    let foreground = Color(red: 0.97, green: 0.96, blue: 0.91)
    var secondary: Color { foreground.opacity(0.70) }
    var rule: Color { foreground.opacity(0.18) }

    func color(for provider: IslandProvider) -> Color {
        switch provider {
        case .claude: return Color(red: 0.96, green: 0.57, blue: 0.42)
        case .codex: return Color(red: 0.52, green: 0.80, blue: 0.98)
        case .antigravity: return Color(red: 0.76, green: 0.66, blue: 0.98)
        case .grok: return Color(red: 0.87, green: 0.96, blue: 0.73)
        case .minimaxCN: return Color(red: 1.0, green: 0.58, blue: 0.34)
        case .deepseek: return Color(red: 0.48, green: 0.66, blue: 1.0)
        case .jev: return Color(red: 0.78, green: 0.62, blue: 1.0)
        }
    }
}
