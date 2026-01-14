import SwiftUI
import SwiftUIBackports

struct ChipButton: View {
    let label: String
    var accessibilityLabel: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .backport.glassEffect(in: .capsule)
        .accessibilityLabel(accessibilityLabel ?? "Insert \(label)")
        .accessibilityAddTraits(.isButton)
    }
}
