import SwiftUI

struct DeviceRow: View {
    enum Trailing {
        case add(() -> Void)
        case reorderRemove(
            canMoveUp: Bool,
            canMoveDown: Bool,
            moveUp: () -> Void,
            moveDown: () -> Void,
            remove: () -> Void
        )
    }

    let title: String
    let subtitle: String?
    let connected: Bool
    let isActive: Bool
    let trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            if let subtitle {
                Text(subtitle)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 18, alignment: .trailing)
            }

            Text(title)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(connected ? .primary : .secondary)
                .italic(!connected)

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.tint)
                    .imageScale(.small)
            }

            Spacer()

            switch trailing {
            case .add(let action):
                Button(action: action) {
                    Image(systemName: "plus.circle")
                }
                .buttonStyle(.borderless)
                .help("Add to priority list")
            case .reorderRemove(let canUp, let canDown, let up, let down, let remove):
                HStack(spacing: 4) {
                    Button(action: up) {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canUp)
                    .help("Move up")

                    Button(action: down) {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(.borderless)
                    .disabled(!canDown)
                    .help("Move down")

                    Button(action: remove) {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove from priority list")
                }
            }
        }
        .padding(.vertical, 2)
    }
}
