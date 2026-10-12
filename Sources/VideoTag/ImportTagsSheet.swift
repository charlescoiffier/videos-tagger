import SwiftUI
import VideoTagCore

/// Choix des tags à importer depuis un autre projet : tous cochés par défaut, sauf ceux déjà présents.
struct ImportTagsSheet: View {
    let sourceName: String
    let existing: [TagDef]
    @State var items: [TagImportItem]
    let onImport: ([TagDef]) -> Void
    let onCancel: () -> Void

    private var selectedCount: Int { items.filter(\.isSelected).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Importer des tags").font(.title3).bold()
            Text("Depuis « \(sourceName) ». Seules les définitions des tags sont copiées (nom, touche, étiquette), pas les cases cochées sur les vidéos. Vos tags existants ne sont jamais modifiés.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            List {
                ForEach($items) { $item in
                    HStack(spacing: 10) {
                        Toggle("", isOn: $item.isSelected)
                            .labelsHidden()
                            .disabled(item.status == .alreadyPresent)
                        Text(item.tag.label).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        if let s = item.tag.shortcut { KeyCap(text: s, small: true) }
                        if let f = item.tag.finder {
                            Circle().fill(f.color.swiftUI).frame(width: 9, height: 9)
                                .help("Étiquette Finder « \(f.name) »")
                        }
                        Spacer(minLength: 8)
                        statusLabel(item.status)
                    }
                    .opacity(item.status == .alreadyPresent ? 0.5 : 1)
                }
            }
            .frame(minHeight: 240)

            HStack {
                Button("Tout cocher") { setAll(true) }.buttonStyle(GhostButtonStyle())
                Button("Tout décocher") { setAll(false) }.buttonStyle(GhostButtonStyle())
                Spacer()
                Button("Annuler", action: onCancel).buttonStyle(GhostButtonStyle())
                Button(selectedCount == 0 ? "Importer" : "Importer \(selectedCount) tag\(selectedCount > 1 ? "s" : "")") {
                    onImport(TagImport.apply(items, to: existing))
                }
                .buttonStyle(PrimaryPillStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(selectedCount == 0)
            }
        }
        .padding(18)
        .frame(width: 560, height: 460)
        .interactiveDismissDisabled()
    }

    private func setAll(_ on: Bool) {
        for i in items.indices where items[i].status != .alreadyPresent { items[i].isSelected = on }
    }

    @ViewBuilder
    private func statusLabel(_ status: TagImportItem.Status) -> some View {
        switch status {
        case .new: LabelChip(text: "nouveau", color: .green)
        case .alreadyPresent: LabelChip(text: "déjà présent : ignoré", color: .secondary)
        case .shortcutDropped: LabelChip(text: "sans sa touche (déjà prise)", color: .orange)
        case .colorDropped: LabelChip(text: "sans étiquette (couleur déjà prise)", color: .orange)
        case .shortcutAndColorDropped: LabelChip(text: "sans touche ni étiquette (déjà prises)", color: .orange)
        }
    }
}
