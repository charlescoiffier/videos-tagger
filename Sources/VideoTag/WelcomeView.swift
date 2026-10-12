import SwiftUI

/// Écran affiché tant qu'aucun dossier n'a été choisi.
struct WelcomeView: View {
    let choose: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Choisissez un dossier de vidéos", systemImage: "folder")
        } description: {
            Text("Video Tag liste les vidéos du dossier et de ses sous-dossiers, et crée un dossier « screen » pour leurs planches.")
        } actions: {
            Button("Choisir un dossier…", action: choose).buttonStyle(PrimaryPillStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.canvas)
    }
}
