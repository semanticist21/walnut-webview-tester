//
//  BookmarkButton.swift
//  wina
//
//  Created by Claude on 12/10/25.
//

import SwiftUI

struct BookmarkButton: View {
    @Binding var showBookmarks: Bool
    let hasBookmarks: Bool

    var body: some View {
        GlassIconButton(
            icon: hasBookmarks ? "bookmark.fill" : "bookmark",
            action: { showBookmarks = true }
        )
    }
}
