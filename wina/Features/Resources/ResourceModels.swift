//
//  ResourceModels.swift
//  wina
//
//  Resource Timing API models for tracking all page resources.
//

import Foundation
import SwiftUI

// MARK: - Resource Entry

struct ResourceEntry: Identifiable, Equatable {
    let id: UUID
    let name: String  // Full URL
    let initiatorType: InitiatorType
    let startTime: Double  // ms from navigation start
    let duration: Double  // ms
    let transferSize: Int  // bytes (0 for cross-origin without TAO header)
    let encodedBodySize: Int
    let decodedBodySize: Int

    // Detailed timing (0 for cross-origin without TAO header)
    let dnsTime: Double  // domainLookupEnd - domainLookupStart
    let tcpTime: Double  // connectEnd - connectStart
    let tlsTime: Double  // connectEnd - secureConnectionStart (if > 0)
    let requestTime: Double  // responseStart - requestStart
    let responseTime: Double  // responseEnd - responseStart

    let timestamp: Date

    // Computed properties
    var displayName: String {
        URL(string: name)?.lastPathComponent ?? name
    }

    var displaySize: String {
        let size = transferSize > 0 ? transferSize :
                   (encodedBodySize > 0 ? encodedBodySize : decodedBodySize)
        guard size > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var displayDuration: String {
        if duration < 1 {
            return "<1ms"
        } else if duration < 1000 {
            return String(format: "%.0fms", duration)
        } else {
            return String(format: "%.2fs", duration / 1000)
        }
    }

    var isCrossOriginRestricted: Bool {
        // If all detailed timings are 0 but duration > 0, it's cross-origin restricted
        transferSize == 0 && dnsTime == 0 && tcpTime == 0 &&
        requestTime == 0 && responseTime == 0 && duration > 0
    }

    var host: String? {
        URL(string: name)?.host
    }
}

// MARK: - Initiator Type

extension ResourceEntry {
    enum InitiatorType: String, CaseIterable, Identifiable {
        case img
        case script
        case link  // CSS
        case css  // CSS from @import
        case font
        case fetch
        case xmlhttprequest
        case beacon
        case video
        case audio
        case other

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .img: "Image"
            case .script: "Script"
            case .link: "Stylesheet"
            case .css: "CSS"
            case .font: "Font"
            case .fetch: "Fetch"
            case .xmlhttprequest: "XHR"
            case .beacon: "Beacon"
            case .video: "Video"
            case .audio: "Audio"
            case .other: "Other"
            }
        }

        var icon: String {
            switch self {
            case .img: "photo"
            case .script: "scroll"
            case .link, .css: "paintbrush"
            case .font: "textformat"
            case .fetch, .xmlhttprequest: "arrow.up.arrow.down"
            case .beacon: "antenna.radiowaves.left.and.right"
            case .video: "video"
            case .audio: "waveform"
            case .other: "questionmark.circle"
            }
        }

        var color: Color {
            switch self {
            case .img: .purple
            case .script: .orange
            case .link, .css: .blue
            case .font: .pink
            case .fetch, .xmlhttprequest: .green
            case .beacon: .cyan
            case .video, .audio: .red
            case .other: .gray
            }
        }

        init(rawString: String) {
            self = InitiatorType(rawValue: rawString.lowercased()) ?? .other
        }
    }
}

// MARK: - Resource Filter

enum ResourceFilter: String, CaseIterable, Identifiable {
    case all
    case img
    case script
    case css
    case font
    case xhr
    case media
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all: "All"
        case .img: "Img"
        case .script: "JS"
        case .css: "CSS"
        case .font: "Font"
        case .xhr: "XHR"
        case .media: "Media"
        case .other: "Other"
        }
    }

    func matches(_ type: ResourceEntry.InitiatorType) -> Bool {
        switch self {
        case .all: true
        case .img: type == .img
        case .script: type == .script
        case .css: type == .link || type == .css
        case .font: type == .font
        case .xhr: type == .fetch || type == .xmlhttprequest
        case .media: type == .video || type == .audio
        case .other: type == .other || type == .beacon
        }
    }
}

// MARK: - Resource Stats

struct ResourceStats {
    let totalCount: Int
    let totalSize: Int
    let totalDuration: Double
    let byType: [ResourceEntry.InitiatorType: (count: Int, size: Int)]

    var displayTotalSize: String {
        guard totalSize > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }
}
