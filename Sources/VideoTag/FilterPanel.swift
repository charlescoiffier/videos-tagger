import SwiftUI
import AppKit
import VideoTagCore

struct FilterPanel: View {
    @Bindable var state: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                TextField("", text: $state.filter.text, prompt: Text("Titre, auteur ou chemin"))
                    .labelsHidden()
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { state.releaseTextFocus() }

                group("Classement") {
                    menuRow("Dossier", selection: $state.filter.folder) {
                        Text("Tous").tag(String?.none)
                        ForEach(state.folders, id: \.self) { folder in
                            Text(folder.isEmpty ? "(racine)" : folder).tag(String?.some(folder))
                        }
                    }
                    menuRow("Revue", selection: $state.filter.review) {
                        Text("Toutes").tag(VideoFilter.Review.any)
                        Text("Revues").tag(VideoFilter.Review.reviewed)
                        Text("Non revues").tag(VideoFilter.Review.unreviewed)
                    }
                }

                group("Tags") {
                    if state.config.tags.isEmpty {
                        Text("Aucun tag défini.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                            GridRow {
                                Color.clear.frame(height: 1)
                                Text("Oui").gridColumnAlignment(.center)
                                Text("Non").gridColumnAlignment(.center)
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            ForEach(state.config.tags) { tag in
                                GridRow {
                                    Text(tag.label).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                    Toggle("", isOn: choiceBinding(tag.key, .yes))
                                        .labelsHidden().toggleStyle(.checkbox)
                                    Toggle("", isOn: choiceBinding(tag.key, .no))
                                        .labelsHidden().toggleStyle(.checkbox)
                                }
                            }
                        }
                    }
                }
            }
            .font(.system(size: 12))
            .controlSize(.small)
            .padding(12)
        }
        .background { Theme.sidebar.ignoresSafeArea() }
        // À l'ouverture du panneau, ne pas laisser le champ de recherche capter le clavier.
        .onAppear { DispatchQueue.main.async { state.releaseTextFocus() } }
    }

    private var header: some View {
        HStack {
            Text("Filtres").font(.system(size: 14, weight: .semibold))
            Spacer()
            Button("Réinitialiser") { state.filter = VideoFilter() }
                .buttonStyle(GhostButtonStyle(accent: true))
                .disabled(state.filter.activeCount == 0)
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }

    private func menuRow<V: Hashable, Content: View>(_ title: String, selection: Binding<V>,
                                                     @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker("", selection: selection, content: content)
                .labelsHidden()
                .frame(maxWidth: 140)
        }
    }

    /// Cases « Oui » / « Non » d'un tag. Les deux cochées, ou aucune : pas de filtre.
    private func choiceBinding(_ key: String, _ choice: TagCriterion.State) -> Binding<Bool> {
        Binding(
            get: { state.filter.tagState(key) == choice },
            set: { on in state.filter.setTag(key, on ? choice : nil) })
    }
}
