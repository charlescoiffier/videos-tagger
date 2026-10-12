import SwiftUI
import AppKit

/// Habillage inspiré de Todoist : fond chaud, accent rouge-orangé, éléments arrondis.
enum Theme {
    static let accent = Color(red: 0.859, green: 0.298, blue: 0.247)
    static let canvas = dynamic(light: (1, 1, 1), dark: (0.12, 0.12, 0.12))
    static let sidebar = dynamic(light: (0.984, 0.969, 0.957), dark: (0.15, 0.15, 0.15))
    static let border = dynamic(light: (0.90, 0.90, 0.90), dark: (0.28, 0.28, 0.28))
    static let hover = dynamic(light: (0.94, 0.92, 0.90), dark: (0.22, 0.22, 0.22))

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            let c = isDark ? dark : light
            return NSColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}

/// Étiquette colorée à la manière des labels Todoist.
struct LabelChip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
    }
}

struct KeyCap: View {
    let text: String
    var onColor = false
    var small = false
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: small ? 10 : 11, weight: .semibold, design: .monospaced))
            .frame(minWidth: small ? 14 : 18)
            .padding(.vertical, 1)
            .background((onColor ? Color.white.opacity(0.25) : Theme.hover), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct GhostButtonStyle: ButtonStyle {
    var accent = false
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.4)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(accent ? Theme.accent : Color.primary.opacity(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background((hovering || configuration.isPressed) ? Theme.hover : .clear, in: RoundedRectangle(cornerRadius: 6))
            .onHover { hovering = $0 }
    }
}

struct PrimaryPillStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(Theme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}
