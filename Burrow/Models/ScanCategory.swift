import Foundation
import SwiftUI

enum ScanCategory: String, CaseIterable, Identifiable, Sendable {
    case systemJunk
    case devJunk
    case largeFiles
    case appLeftovers
    case duplicates
    case browserData
    case backups
    case xcode
    case mail
    case malware

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemJunk:   "System Junk"
        case .devJunk:      "Developer Junk"
        case .largeFiles:   "Large & Old Files"
        case .appLeftovers: "App Leftovers"
        case .duplicates:   "Duplicates"
        case .browserData:  "Browser Data"
        case .backups:      "iOS Backups"
        case .xcode:        "Xcode Junk"
        case .mail:         "Mail Attachments"
        case .malware:      "Malware"
        }
    }

    var symbol: String {
        switch self {
        case .systemJunk:   "trash.circle"
        case .devJunk:      "hammer"
        case .largeFiles:   "doc.zipper"
        case .appLeftovers: "app.badge.checkmark"
        case .duplicates:   "doc.on.doc"
        case .browserData:  "safari"
        case .backups:      "iphone"
        case .xcode:        "wrench.and.screwdriver"
        case .mail:         "envelope"
        case .malware:      "shield.lefthalf.filled"
        }
    }

    var tint: Color {
        switch self {
        case .systemJunk:   .blue
        case .devJunk:      .orange
        case .largeFiles:   .purple
        case .appLeftovers: .pink
        case .duplicates:   .teal
        case .browserData:  .indigo
        case .backups:      .mint
        case .xcode:        .gray
        case .mail:         .yellow
        case .malware:      .red
        }
    }
}

/// Stable identifier for a scanner. Strings, not enums, so plugins can
/// register their own scanners without touching the core.
struct ScannerID: Hashable, Sendable, RawRepresentable {
    let rawValue: String
    init(_ raw: String) { rawValue = raw }
    init(rawValue: String) { self.rawValue = rawValue }
}
