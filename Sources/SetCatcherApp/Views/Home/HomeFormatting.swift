import Foundation
import SetCatcherCore
import SwiftUI

enum HomeFormatting {
    static func greeting(profile: DJProfile, now: Date = Date(), calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        let part: String
        switch hour {
        case 5..<12:
            part = "Good morning"
        case 12..<17:
            part = "Good afternoon"
        default:
            part = "Good evening"
        }
        if let name = profile.firstName {
            return "\(part), \(name)"
        }
        return part
    }

    static func formatDuration(_ seconds: Double?) -> String {
        guard let seconds else { return "—" }
        let total = Int(seconds.rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    static func protectionTone(_ state: ProtectionState) -> StatusTone {
        switch state {
        case .protected:
            return .ok
        case .needsSetup:
            return .warn
        case .scanning:
            return .info
        case .attentionNeeded:
            return .danger
        }
    }

    static func liveTone(_ state: LiveProtectionState) -> StatusTone {
        switch state.primaryDisplay {
        case .noSource: return .neutral
        case .detected, .armed: return .warn
        case .ready, .setProtected: return .ok
        case .capturing: return .danger
        case .saving: return .info
        case .attentionNeeded: return .danger
        }
    }

    static func setupTone(_ state: AppSetupState) -> StatusTone {
        switch state {
        case .watching, .archived:
            return .ok
        case .saving:
            return .info
        case .recordingDetected, .needsFolderAccess, .appNotFound:
            return .warn
        case .attentionNeeded, .error:
            return .danger
        }
    }

    static func lastSetSubtitle(_ summary: LibrarySessionSummary) -> String {
        let place = [summary.context.venue, summary.context.city].filter { !$0.isEmpty }.joined(separator: ", ")
        let archived = summary.archive.detectedAt.formatted(date: .abbreviated, time: .shortened)
        if place.isEmpty { return "Archived \(archived)" }
        return "\(place) · Archived \(archived)"
    }
}
