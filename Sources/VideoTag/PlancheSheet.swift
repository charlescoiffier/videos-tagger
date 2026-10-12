import SwiftUI
import VideoTagCore

struct PlancheSheet: View {
    @Bindable var state: AppState
    @Bindable var runner: PlancheRunner
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Générer les planches").font(.title2).bold()

            switch runner.phase {
            case .idle:
                Text("\(PlancheContact.missingCount(videos: state.videos)) vidéo(s) n'ont pas de planche. Video Tag les crée avec le script planche-contact, dans le dossier « \(state.config.planches.folder) », sous le nom <préfixe><nom de la vidéo><suffixe>.<format>. Les planches déjà présentes sont conservées (sauf « Écraser »). Cela peut prendre plusieurs minutes.")
                    .foregroundStyle(.secondary)
                settingsForm
            case .running:
                ProgressView(value: Double(runner.folderIndex), total: Double(max(runner.folders.count, 1)))
                Text("Dossier \(runner.folderIndex) sur \(runner.folders.count) : \(runner.current)").font(.callout)
                counters
            case .finished:
                Label("Terminé", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                counters
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }

            if !runner.log.isEmpty {
                ScrollView {
                    Text(runner.log.suffix(60).joined(separator: "\n"))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 160)
                .padding(8)
                .background(Theme.sidebar, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Spacer()
                switch runner.phase {
                case .idle:
                    Button("Annuler") { dismiss() }.buttonStyle(GhostButtonStyle())
                    Button("Générer") { start() }
                        .buttonStyle(PrimaryPillStyle())
                        .disabled(!state.config.planches.validationErrors.isEmpty)
                case .running:
                    Button("Arrêter") { runner.cancel() }.buttonStyle(GhostButtonStyle())
                default:
                    Button("Fermer") { dismiss() }.buttonStyle(PrimaryPillStyle())
                }
            }
        }
        .padding(20)
        .frame(width: 680)
        .interactiveDismissDisabled(runner.isRunning)
    }

    private var settingsForm: some View {
        let errors = state.config.planches.validationErrors
        return VStack(alignment: .leading, spacing: 10) {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                GridRow {
                    field("Nombre de captures", int($state.config.planches.captures))
                    field("Colonnes", int($state.config.planches.columns))
                }
                GridRow {
                    field("Largeur d'une capture (px)", int($state.config.planches.thumbnailWidth))
                    field("Qualité JPEG (%)", int($state.config.planches.quality))
                }
                GridRow {
                    field("Marge entre les images (px)", int($state.config.planches.innerMargin))
                    field("Marge autour du damier (px)", int($state.config.planches.outerMargin))
                }
                GridRow {
                    field("Couleur de fond", text($state.config.planches.background, prompt: "black ou 0x202020"))
                    field("Format") {
                        Picker("", selection: $state.config.planches.format) {
                            Text("jpg").tag("jpg")
                            Text("png").tag("png")
                        }
                        .pickerStyle(.segmented).labelsHidden().frame(width: 110)
                    }
                }
                GridRow {
                    field("Préfixe du fichier", text($state.config.planches.prefix, prompt: "aucun"))
                    field("Suffixe du fichier", text($state.config.planches.suffix, prompt: "aucun"))
                }
                GridRow {
                    field("Dossier des planches", text($state.config.planches.folder, prompt: "screen"))
                    Toggle("Écraser l'existant", isOn: $state.config.planches.overwrite)
                }
            }
            HStack(spacing: 10) {
                Button("Valeurs du script") {
                    let folder = state.config.planches.folder
                    state.config.planches = .scriptDefaults
                    state.config.planches.folder = folder
                }
                .buttonStyle(GhostButtonStyle())
                .help("Réglages par défaut du script planche-contact : 12 captures, 4 colonnes, préfixe « planche_ »")
                Button("Réglages d'origine de Video Tag") { state.config.planches = PlancheSettings() }
                    .buttonStyle(GhostButtonStyle())
            }
            Text("Changer le préfixe, le suffixe, le format ou le dossier change les noms attendus : les planches déjà créées sous un autre nom ne seront plus reconnues.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(errors, id: \.self) { Text($0).font(.caption).foregroundStyle(.red) }
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(title).font(.system(size: 12)).frame(width: 170, alignment: .leading)
            content()
        }
    }

    private func field(_ title: String, _ content: some View) -> some View {
        field(title) { content }
    }

    private func int(_ binding: Binding<Int>) -> some View {
        TextField("", value: binding, format: .number.grouping(.never))
            .textFieldStyle(.roundedBorder).frame(width: 90)
    }

    private func text(_ binding: Binding<String>, prompt: String) -> some View {
        TextField("", text: binding, prompt: Text(prompt))
            .textFieldStyle(.roundedBorder).frame(width: 130)
    }

    private var counters: some View {
        Text("\(runner.created) créée(s) · \(runner.skipped) déjà présente(s) · \(runner.failed) en échec")
            .font(.caption).foregroundStyle(.secondary)
    }

    private func start() {
        guard let root = state.root else { return }
        let folders = PlancheContact.foldersToProcess(videos: state.videos)
        state.saveConfig()
        let settings = state.config.planches
        Task {
            await runner.run(root: root, folders: folders, settings: settings)
            state.scan(announce: false)
        }
    }
}
