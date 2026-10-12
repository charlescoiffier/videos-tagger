import SwiftUI
import VideoTagCore

/// Fenêtre modale « Informations de la vidéo » : titre, date, auteur.
struct InfoSheet: View {
    @Bindable var state: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var draft = VideoInfoDraft(title: "", date: "", author: "")

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Informations de la vidéo").font(.title3).bold()
            if let v = state.selected {
                Text(v.path).font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
                GridRow {
                    Text("Titre")
                    TextField("Titre", text: $draft.title).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Date")
                    TextField("AAAA-MM-JJ", text: $draft.date).textFieldStyle(.roundedBorder)
                }
                GridRow {
                    Text("Auteur")
                    TextField("Auteur", text: $draft.author).textFieldStyle(.roundedBorder)
                }
            }

            let errors = draft.errors
            ForEach(errors, id: \.self) { Text($0).font(.caption).foregroundStyle(.red) }

            HStack {
                Spacer()
                Button("Annuler") { dismiss() }.buttonStyle(GhostButtonStyle())
                Button("Enregistrer") {
                    state.updateInfo(draft)
                    dismiss()
                }
                .buttonStyle(PrimaryPillStyle())
                .keyboardShortcut(.defaultAction)
                .disabled(!errors.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 460)
        .onAppear { if let v = state.selected { draft = VideoInfoDraft(video: v) } }
    }
}
