import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var model: IslandModel

    var body: some View {
        ExpandedView(model: model)
            .frame(width: 800, height: 320)
            .background(Color(red: 0.020, green: 0.020, blue: 0.027))
            .preferredColorScheme(.dark)
    }
}
