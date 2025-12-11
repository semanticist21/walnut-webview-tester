//
//  BackButton.swift
//  wina
//

import SwiftUI

struct BackButton: View {
    let action: () -> Void

    var body: some View {
        GlassIconButton(icon: "chevron.left") {
            action()
        }
    }
}

#Preview {
    BackButton {
        print("Back")
    }
}
