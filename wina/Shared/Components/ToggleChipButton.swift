import SwiftUI

struct ToggleChipButton: View {
    @Binding var isOn: Bool
    let label: String

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundStyle(isOn ? .primary : .tertiary)
                    .contentTransition(.symbolEffect(.replace))

                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isOn ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .glassEffect(in: .rect(cornerRadius: 12))
    }
}
