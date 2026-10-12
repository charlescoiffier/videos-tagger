import SwiftUI
import VideoTagCore

extension TagColor {
    var swiftUI: Color {
        switch self {
        case .gray: return .gray
        case .green: return .green
        case .purple: return .purple
        case .blue: return .blue
        case .yellow: return .yellow
        case .red: return .red
        case .orange: return .orange
        }
    }

    var label: String {
        switch self {
        case .gray: return "Gris"
        case .green: return "Vert"
        case .purple: return "Violet"
        case .blue: return "Bleu"
        case .yellow: return "Jaune"
        case .red: return "Rouge"
        case .orange: return "Orange"
        }
    }
}
