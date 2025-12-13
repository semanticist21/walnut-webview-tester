//
//  GlassIconButton.swift
//  wina
//

import SwiftUI

struct GlassIconButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .glassEffect(in: .circle)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    GlassIconButton(icon: "gearshape") {}
}
