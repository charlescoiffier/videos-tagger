import SwiftUI
import AppKit
import VideoTagCore

struct ContentView: View {
    @Bindable var state: AppState
    @State private var showSettings = false
    @State private var showInfo = false
    @State private var showFilters = true
    @State private var showPlanches = false
    @State private var runner = PlancheRunner()
    @State private var monitor: Any?

    var body: some View {
        Group {
            if state.root == nil {
                WelcomeView(choose: chooseFolder)
            } else {
                mainView
            }
        }
        .tint(Theme.accent)
        .background(Theme.canvas)
        .sheet(isPresented: $showSettings) { SettingsView(state: state) }
        .sheet(isPresented: $showInfo) { InfoSheet(state: state) }
        .sheet(isPresented: $showPlanches) { PlancheSheet(state: state, runner: runner) }
        .onChange(of: showSettings) { _, _ in updateKeysEnabled() }
        .onChange(of: showInfo) { _, _ in updateKeysEnabled() }
        .onChange(of: showPlanches) { _, open in
            if open { runner.phase = .idle }
            updateKeysEnabled()
        }
        .onChange(of: state.selectedID) { _, _ in QuickLookController.shared.update(url: state.selectedFileURL) }
        .alert("Erreur", isPresented: Binding(get: { state.errorMessage != nil },
                                              set: { if !$0 { state.errorMessage = nil } })) {
            Button("OK") {}
        } message: { Text(state.errorMessage ?? "") }
        .alert("Information", isPresented: Binding(get: { state.notice != nil },
                                                   set: { if !$0 { state.notice = nil } })) {
            Button("OK") {}
        } message: { Text(state.notice ?? "") }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            state.reloadIfChangedExternally()
            WindowFit.keepAboveDock()
        }
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps: true)
            if state.root != nil {
                state.load()
                if state.isLoaded && state.videos.isEmpty { state.scan() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { WindowFit.keepAboveDock() }
            if monitor == nil {
                monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                    MainActor.assumeIsolated { state.handleKey(event) } ? nil : event
                }
            }
        }
        .onDisappear {
            if let monitor { NSEvent.removeMonitor(monitor) }
            monitor = nil
        }
    }

    private var mainView: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 320)
        } detail: {
            SorterView(state: state, openSettings: { showSettings = true })
        }
        .inspector(isPresented: $showFilters) {
            FilterPanel(state: state)
                .inspectorColumnWidth(min: 240, ideal: 260, max: 380)
        }
        .navigationTitle("Video Tag")
        .navigationSubtitle("\(state.filtered.count) vidéos")
        .toolbar { toolbarContent }
    }

    private func updateKeysEnabled() {
        state.keysEnabled = !(showSettings || showInfo || showPlanches)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        let missing = PlancheContact.missingCount(videos: state.videos)
        ToolbarItemGroup {
            iconButton("folder", help: "Dossier analysé : \(state.root?.path ?? "aucun")\nCliquez pour en choisir un autre. Video Tag liste les vidéos du dossier et de ses sous-dossiers ; le dossier « screen » est créé s'il manque.") {
                chooseFolder()
            }
            iconButton("square.and.pencil", help: "Modifier les informations de la vidéo : titre, date, auteur.") {
                showInfo = true
            }
            .disabled(state.selected == nil)
            iconButton("arrow.triangle.2.circlepath",
                       help: "Mettre à jour la base : parcourt le dossier, ajoute les nouvelles vidéos à videos.json et signale celles qui ont disparu. Ne modifie ni vos tags, ni vos revues, ni vos infos.") {
                state.scan()
            }
            iconButton("photo.on.rectangle.angled",
                       help: missing > 0 ? "Générer les \(missing) planche(s) manquante(s) avec le script planche-contact (dossier « screen »)" : "Aucune planche manquante",
                       highlighted: missing > 0) { showPlanches = true }
                .disabled(missing == 0)
            iconButton("tag", help: "Réappliquer les étiquettes Finder : repose sur les fichiers vidéo les étiquettes des tags cochés.") {
                state.resyncAllTags()
            }
            iconButton("slider.horizontal.3",
                       help: "Réglages des tags : créer, renommer, supprimer, choisir la touche et l'étiquette Finder.",
                       highlighted: state.config.tags.isEmpty) { showSettings = true }
        }
        ToolbarItem(placement: .primaryAction) {
            iconButton("sidebar.right",
                       help: showFilters ? "Masquer le panneau de recherche et de filtres" : "Afficher le panneau de recherche et de filtres",
                       highlighted: state.filter.activeCount > 0) { showFilters.toggle() }
        }
    }

    private func iconButton(_ symbol: String, help: String, highlighted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .foregroundStyle(highlighted ? Theme.accent : Color.primary)
        }
        .help(help)
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = state.root
        panel.prompt = "Analyser ce dossier"
        panel.message = "Choisissez le dossier qui contient vos vidéos (les sous-dossiers sont analysés aussi)."
        if panel.runModal() == .OK, let url = panel.url { state.setRoot(url) }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(state.filtered) { v in
                            Button { state.selectedID = v.id; state.releaseTextFocus() } label: {
                                VideoRow(video: v, tags: state.config.tags, selected: v.id == state.selectedID)
                            }
                            .buttonStyle(.plain)
                            .id(v.id)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: state.selectedID) { _, id in
                    if let id { withAnimation(.easeOut(duration: 0.15)) { proxy.scrollTo(id) } }
                }
            }
            Divider()
            status
        }
        .background(Theme.sidebar)
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(state.filtered.count) affichées sur \(state.videos.count) · \(state.reviewedCount) revues (\(state.reviewedPercent) %)")
            if let r = state.report, !(r.withoutScreen.isEmpty && r.missing.isEmpty) {
                Text("Dernière mise à jour : \(r.added.count) ajoutées, \(r.missing.count) disparues, \(r.withoutScreen.count) sans planche")
            }
            if let r = state.report, !r.duplicateNames.isEmpty {
                Text("⚠️ \(r.duplicateNames.count) nom(s) de fichier en double")
                    .help(r.duplicateNames.map { "\($0.name) : \($0.paths.joined(separator: ", "))" }.joined(separator: "\n"))
            }
            if !state.isLoaded { Text("Base non chargée : écritures désactivées").foregroundStyle(.red) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
    }
}
