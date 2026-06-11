import Foundation
import SwiftUI

enum TalkModel: String, CaseIterable, Identifiable {
    case haiku, sonnet, opus
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku:  "Haiku 4.5 — fastest"
        case .sonnet: "Sonnet 4.6 — balanced"
        case .opus:   "Opus 4.7 — best"
        }
    }
    var wire: String {
        switch self {
        case .haiku:  "claude-haiku-4-5"
        case .sonnet: "claude-sonnet-4-6"
        case .opus:   "claude-opus-4-7"
        }
    }
}

enum TalkEffort: String, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .low:    "Low — quick & shallow"
        case .medium: "Medium — default"
        case .high:   "High — multi-step, slower"
        }
    }
}

// Centralized @AppStorage keys, shared across views.
enum TalkSettingsKey {
    static let model  = "talk.model"
    static let effort = "talk.effort"
    static let speak  = "talk.speakReplies"
}
