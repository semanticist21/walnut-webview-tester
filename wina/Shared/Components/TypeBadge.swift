//
//  TypeBadge.swift
//  wina
//
//  Reusable type badge component for content type indicators.
//

import SwiftUI

struct TypeBadge: View {
    let text: String
    let color: Color
    var icon: String?

    var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
            }
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color, in: RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    HStack(spacing: 8) {
        TypeBadge(text: "JSON", color: .purple, icon: "curlybraces")
        TypeBadge(text: "#", color: .blue)
        TypeBadge(text: "Bool", color: .green, icon: "checkmark")
    }
    .padding()
}
