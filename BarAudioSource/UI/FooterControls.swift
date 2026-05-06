import AppKit
import SwiftUI

struct FooterControls: View {
    @EnvironmentObject private var store: PriorityStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Pause enforcement", isOn: $store.paused)
            Toggle("Launch at login", isOn: $store.launchAtLogin)
            HStack {
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q")
            }
            .padding(.top, 4)
        }
    }
}
