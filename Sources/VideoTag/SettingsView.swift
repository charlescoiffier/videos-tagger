import SwiftUI
import AppKit
import VideoTagCore

struct SettingsView: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var original: [TagDef] = []
    @State private var pendingDelete: TagDef?
    @State private var importItems: [TagImportItem]?
    @State private var importSource = ""
    @State private var importError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tags").font(.title2).bold()

            List {
                ForEach($state.config.tags) { $tag in
                    row($tag).listRowSeparator(.visible)
                }
                .onMove { state.config.tags.move(fromOffsets: $0, toOffset: $1) }
            }
            .frame(minHeight: 260)

            let errors = state.config.validationErrors()
            ForEach(errors, id: \.self) { Text($0).foregroundStyle(.red).font(.caption) }

            HStack {
                Button("Ajouter un tag") { addTag() }.buttonStyle(GhostButtonStyle(accent: true))
                Button("Importer des tags…") { chooseProject() }
                    .buttonStyle(GhostButtonStyle())
                    .help("Copie les définitions de tags d'un autre projet (un autre dossier ouvert dans Video Tag). Rien n'est modifié dans ce projet-là.")
                Spacer()
                Button("Fermer") { close() }
                    .buttonStyle(PrimaryPillStyle())
                    .keyboardShortcut(.defaultAction)
                    .disabled(!errors.isEmpty)
            }
        }
        .padding(18)
        .frame(width: 720, height: 520)
        .interactiveDismissDisabled()
        .onAppear { original = state.config.tags }
        .sheet(isPresented: Binding(get: { importItems != nil }, set: { if !$0 { importItems = nil } })) {
            if let items = importItems {
                ImportTagsSheet(sourceName: importSource, existing: state.config.tags, items: items,
                                onImport: { state.config.tags = $0; importItems = nil },
                                onCancel: { importItems = nil })
            }
        }
        .alert("Import impossible", isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })) {
            Button("OK") {}
        } message: { Text(importError ?? "") }
        .confirmationDialog("Supprimer ce tag ?", isPresented: Binding(
            get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })) {
            Button("Supprimer et retirer son étiquette", role: .destructive) {
                if let t = pendingDelete { state.config.tags.removeAll { $0.key == t.key } }
                pendingDelete = nil
            }
        }
    }

    /// Couleurs d'étiquette encore libres pour ce tag (la sienne comprise).
    private func availableColors(for key: String) -> [TagColor] {
        let used = Set(state.config.tags.filter { $0.key != key }.compactMap { $0.finder?.color })
        return TagColor.allCases.filter { !used.contains($0) }
    }

    private func row(_ tag: Binding<TagDef>) -> some View {
        let key = tag.wrappedValue.key
        let colors = availableColors(for: key)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal").foregroundStyle(.tertiary)
                    .help("Glissez la ligne pour réorganiser")

                TextField("Nom", text: tag.label)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 150)

                ShortcutRecorder(shortcut: tag.shortcut)
                    .frame(width: 100)

                Toggle("Étiquette", isOn: Binding(
                    get: { tag.wrappedValue.finder != nil },
                    set: { on in
                        if on, let color = colors.first {
                            tag.wrappedValue.finder = FinderTag(name: tag.wrappedValue.label, color: color)
                        } else {
                            tag.wrappedValue.finder = nil
                        }
                    }))
                    .disabled(tag.wrappedValue.finder == nil && colors.isEmpty)
                    .help(colors.isEmpty && tag.wrappedValue.finder == nil
                          ? "Les 7 couleurs d'étiquette sont déjà utilisées"
                          : "Poser une étiquette Finder colorée sur les vidéos de ce tag")

                if tag.wrappedValue.finder != nil {
                    TextField("Nom de l'étiquette", text: Binding(
                        get: { tag.wrappedValue.finder?.name ?? "" },
                        set: { tag.wrappedValue.finder?.name = $0 }))
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 100)
                    colorMenu(tag, colors: colors)
                }
                Spacer(minLength: 0)
                Button(role: .destructive) { pendingDelete = tag.wrappedValue } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("Supprimer ce tag")
            }
        }
        .padding(.vertical, 3)
    }

    /// Menu de couleur réduit à un rond coloré (les entrées montrent aussi leur couleur).
    private func colorMenu(_ tag: Binding<TagDef>, colors: [TagColor]) -> some View {
        let current = tag.wrappedValue.finder?.color ?? .green
        return Menu {
            ForEach(colors, id: \.self) { c in
                Button {
                    tag.wrappedValue.finder?.color = c
                } label: {
                    Label { Text(c.label) } icon: { Image(nsImage: Self.dot(c.swiftUI)) }
                }
            }
        } label: {
            Image(nsImage: Self.dot(current.swiftUI, size: 16))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
        .help("Couleur de l'étiquette Finder : \(current.label)")
    }

    private static func dot(_ color: Color, size: CGFloat = 12) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor(color).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 0.5, dy: 0.5)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }

    /// Choix d'un autre projet (dossier contenant un `config.json`), puis lecture seule de ses tags.
    private func chooseProject() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Importer ses tags"
        panel.message = "Choisissez un autre dossier de vidéos déjà ouvert dans Video Tag (il contient un fichier config.json)."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if let current = state.root, url.standardizedFileURL == current.standardizedFileURL {
            importError = "C'est le dossier en cours : choisissez un autre projet."
            return
        }
        do {
            let incoming = try TagImport.load(from: url)
            importSource = url.lastPathComponent
            importItems = TagImport.plan(existing: state.config.tags, incoming: incoming)
        } catch TagImportError.noTags {
            importError = "Ce dossier n'a pas de tags à importer : il ne contient pas de config.json, ou celui-ci ne définit aucun tag."
        } catch {
            importError = "Lecture impossible : \(error.localizedDescription)"
        }
    }

    private func addTag() {
        var n = 1
        while state.config.tags.contains(where: { $0.key == "tag-\(n)" }) { n += 1 }
        state.config.tags.append(TagDef(key: "tag-\(n)", label: "Nouveau tag"))
    }

    private func close() {
        state.saveConfig()
        // Les étiquettes Finder ne sont à reposer que si une étiquette a changé (nom, couleur, ajout, retrait)
        // ou si un tag portant une étiquette a été supprimé. Renommer un tag, changer sa touche, son motif
        // ou l'ordre n'a aucun effet sur les fichiers.
        let finderMap: ([TagDef]) -> [String: FinderTag] = { tags in
            Dictionary(uniqueKeysWithValues: tags.compactMap { t in t.finder.map { (t.key, $0) } })
        }
        if finderMap(state.config.tags) != finderMap(original) {
            state.resyncAllTags(previous: original, announce: false)
        }
        dismiss()
    }
}
