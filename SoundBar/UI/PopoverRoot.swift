import SwiftUI

struct PopoverRoot: View {
    @EnvironmentObject private var store: PriorityStore
    @EnvironmentObject private var coordinator: AudioCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScopeSection(scope: .output)
            Divider().padding(.vertical, 8)
            ScopeSection(scope: .input)
            Divider().padding(.vertical, 8)
            FooterControls()
        }
        .padding(12)
        .frame(width: 360)
    }
}
