//
//  InfoButton.swift
//  wina
//

import SwiftUI

struct InfoButton: View {
    @State private var showInfo = false

    var body: some View {
        GlassIconButton(icon: "info.circle") {
            showInfo = true
        }
        .sheet(isPresented: $showInfo) {
            InfoView()
        }
    }
}

#Preview {
    InfoButton()
}
