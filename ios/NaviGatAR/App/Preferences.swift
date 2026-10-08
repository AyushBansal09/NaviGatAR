import SwiftUI
import UIKit

enum SettingsKey {
    static let hasSeenOnboarding = "hasSeenOnboarding"
    static let voiceGuidance = "voiceGuidance"
    static let haptics = "haptics"
    static let pathStyle = "pathStyle"
    static let pathColor = "pathColor"
    static let highContrast = "highContrast"
    static let largeText = "largeText"
    static let imperialUnits = "imperialUnits"
    static let stepFreeDefault = "stepFreeDefault"
    static let selectedBuilding = "selectedBuilding"
}

enum Brand {
    static let purple = Color(red: 0.42, green: 0.29, blue: 0.76)
    static let lavender = Color(red: 0.93, green: 0.90, blue: 0.99)
}

enum PathStyle: String, CaseIterable, Identifiable {
    case spheres, arrows, dots
    var id: String { rawValue }
    var title: String {
        switch self {
        case .spheres: return "Spheres"
        case .arrows: return "Arrows"
        case .dots: return "Small dots"
        }
    }
}

enum PathColor: String, CaseIterable, Identifiable {
    case cyan, purple, green, orange, yellow
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var uiColor: UIColor {
        switch self {
        case .cyan: return UIColor(red: 0.35, green: 0.80, blue: 0.95, alpha: 1)
        case .purple: return UIColor(red: 0.60, green: 0.40, blue: 0.95, alpha: 1)
        case .green: return UIColor(red: 0.25, green: 0.85, blue: 0.45, alpha: 1)
        case .orange: return UIColor(red: 1.00, green: 0.58, blue: 0.15, alpha: 1)
        case .yellow: return UIColor(red: 1.00, green: 0.90, blue: 0.10, alpha: 1)
        }
    }
    var color: Color { Color(uiColor: uiColor) }
}

/// Snapshot of the guidance preferences, read when a navigation starts.
struct GuidanceSettings {
    var voice = true
    var haptics = true
    var style: PathStyle = .spheres
    var color: PathColor = .cyan
    var highContrast = false
    var largeText = false
    var imperial = false

    static var current: GuidanceSettings {
        let d = UserDefaults.standard
        var s = GuidanceSettings()
        s.voice = d.object(forKey: SettingsKey.voiceGuidance) as? Bool ?? true
        s.haptics = d.object(forKey: SettingsKey.haptics) as? Bool ?? true
        s.style = PathStyle(rawValue: d.string(forKey: SettingsKey.pathStyle) ?? "") ?? .spheres
        s.color = PathColor(rawValue: d.string(forKey: SettingsKey.pathColor) ?? "") ?? .cyan
        s.highContrast = d.bool(forKey: SettingsKey.highContrast)
        s.largeText = d.bool(forKey: SettingsKey.largeText)
        s.imperial = d.bool(forKey: SettingsKey.imperialUnits)
        return s
    }

    func distance(_ metres: Float) -> String { DistanceText.string(metres, imperial: imperial) }
}
