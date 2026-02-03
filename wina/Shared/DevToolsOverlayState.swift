//
//  DevToolsOverlayState.swift
//  wina
//
//  Created by Claude on 2/3/26.
//

import SwiftUI

enum DevToolsOverlay: String, Hashable, CaseIterable {
    case console
    case network
    case storage
    case performance
    case editor
    case accessibility
    case snippets
    case searchText
}

@Observable
final class DevToolsOverlayState {
    var active: Set<DevToolsOverlay> = []

    func open(_ overlay: DevToolsOverlay) {
        active.insert(overlay)
    }

    func close(_ overlay: DevToolsOverlay) {
        active.remove(overlay)
    }

    func toggle(_ overlay: DevToolsOverlay) {
        if active.contains(overlay) {
            active.remove(overlay)
        } else {
            active.insert(overlay)
        }
    }

    func closeAll() {
        active.removeAll()
    }

    func isOpen(_ overlay: DevToolsOverlay) -> Bool {
        active.contains(overlay)
    }

    func binding(for overlay: DevToolsOverlay) -> Binding<Bool> {
        Binding(
            get: { self.active.contains(overlay) },
            set: { $0 ? self.open(overlay) : self.close(overlay) }
        )
    }
}
