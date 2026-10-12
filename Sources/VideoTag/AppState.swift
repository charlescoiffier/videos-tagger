import AppKit
import Foundation
import Observation
import VideoTagCore

@MainActor @Observable
final class AppState {
    var root: URL?
    var config = Config()
    var videos: [Video] = []
    var filter = VideoFilter() {
        // Quand le filtre change, la vidéo sélectionnée doit y répondre : sinon on prend la première qui y répond.
        didSet { selectedID = filter.reconciledSelection(current: selectedID, videos: videos) }
    }
    var selectedID: String?
    var report: ScanReport?
    var errorMessage: String?
    var notice: String?
    /// Verrou : activé, les tags ne peuvent plus être cochés ni décochés sur les vidéos (clic comme clavier).
    var tagsLocked = UserDefaults.standard.bool(forKey: "tagValuesLocked") {
        didSet { UserDefaults.standard.set(tagsLocked, forKey: "tagValuesLocked") }
    }
    /// Faux quand une fenêtre de saisie est ouverte : les raccourcis clavier sont suspendus.
    var keysEnabled = true
    /// Vrai seulement si la base a été lue sans erreur : sinon aucune écriture n'est permise.
    private(set) var isLoaded = false
    private var didBackup = false
    private var knownModification: Date?

    init() {
        if let saved = UserDefaults.standard.string(forKey: "root") {
            root = URL(fileURLWithPath: saved)
        }
    }

    private var files: LibraryFiles? { root.map { LibraryFiles(root: $0) } }

    var filtered: [Video] { videos.filter { filter.matches($0) } }
    var selected: Video? { videos.first { $0.id == selectedID } }
    var folders: [String] { Array(Set(videos.map(\.folder))).sorted() }
    var reviewedCount: Int { videos.filter(\.reviewed).count }
    var reviewedPercent: Int {
        videos.isEmpty ? 0 : Int((Double(reviewedCount) / Double(videos.count) * 100).rounded())
    }
    var selectedFileURL: URL? {
        guard let root, let selected else { return nil }
        return root.appendingPathComponent(selected.path)
    }

    /// Rend le clavier à la fenêtre (sinon le champ de recherche, s'il a le focus, absorbe espace et les touches des tags).
    func releaseTextFocus() { NSApp.keyWindow?.makeFirstResponder(nil) }

    func toggleQuickLook() { QuickLookController.shared.toggle(url: selectedFileURL) }

    func setRoot(_ url: URL) {
        root = url
        UserDefaults.standard.set(url.path, forKey: "root")
        videos = []
        config = Config()
        filter = VideoFilter()
        selectedID = nil
        report = nil
        didBackup = false
        load()
        if isLoaded && videos.isEmpty { scan() }
    }

    func load() {
        isLoaded = false
        guard let root, let files else { return }
        do {
            guard FileManager.default.fileExists(atPath: root.path) else {
                throw StoreError.rootUnavailable(root.path)
            }
            config = try files.loadConfig() ?? Config()
            videos = try files.loadDatabase()?.videos ?? []
            knownModification = files.databaseModificationDate()
            isLoaded = true
            errorMessage = nil
            selectedID = filter.reconciledSelection(current: selectedID, videos: videos)
        } catch {
            errorMessage = "Chargement impossible (aucune écriture ne sera faite) : \(error)"
        }
    }

    /// Recharge la base si un autre programme (le script video-tag-import) l'a modifiée.
    func reloadIfChangedExternally() {
        guard isLoaded, let files else { return }
        let current = files.databaseModificationDate()
        guard current != knownModification else { return }
        do {
            guard let db = try files.loadDatabase() else { return }
            videos = db.videos
            knownModification = current
            selectedID = filter.reconciledSelection(current: selectedID, videos: videos)
            notice = "videos.json a été modifié par un autre programme : la liste a été rechargée."
        } catch {
            errorMessage = "Rechargement impossible : \(error)"
        }
    }

    func scan(announce: Bool = true) {
        guard isLoaded, let root, let files else { return }
        do {
            if !didBackup { try JSONFile<Database>(url: files.databaseURL).backup(); didBackup = true }
            let createdScreen = try LibraryScanner.ensureScreenFolder(root: root, settings: config.planches)
            var out = try LibraryScanner.scan(root: root, existing: videos, settings: config.planches)
            out.report.createdScreenFolder = createdScreen
            videos = out.videos
            report = out.report
            try save()
            selectedID = filter.reconciledSelection(current: selectedID, videos: videos)
            let r = out.report
            if announce {
                var text = r.createdScreenFolder ? "Le dossier « \(config.planches.folder) » a été créé dans \(root.lastPathComponent).\n\n" : ""
                text += "videos.json mis à jour : \(r.added.count) vidéo(s) ajoutée(s), \(r.missing.count) disparue(s) du disque (conservées dans la base), \(r.withoutScreen.count) sans planche.\n\nVos tags, vos revues et vos infos ne sont pas modifiés."
                if !r.duplicateNames.isEmpty {
                    text += "\n\n⚠️ \(r.duplicateNames.count) nom(s) de fichier en double (même nom dans des dossiers différents ; ces vidéos partagent la même planche) :"
                    for d in r.duplicateNames.prefix(8) { text += "\n• \(d.name) : \(d.paths.joined(separator: ", "))" }
                    if r.duplicateNames.count > 8 { text += "\n… et \(r.duplicateNames.count - 8) autre(s)." }
                }
                notice = text
            }
        } catch {
            errorMessage = "Mise à jour impossible : \(error)"
        }
    }

    private func save() throws {
        guard isLoaded, let files else { return }
        try files.saveDatabase(Database(videos: videos))
        knownModification = files.databaseModificationDate()
    }

    func saveConfig() {
        guard isLoaded, let files else { return }
        do { try files.saveConfig(config) } catch { errorMessage = "Enregistrement des tags impossible : \(error)" }
    }

    // MARK: - Infos générales

    func updateInfo(_ draft: VideoInfoDraft) {
        guard isLoaded, draft.errors.isEmpty, let i = videos.firstIndex(where: { $0.id == selectedID }) else { return }
        videos[i] = draft.applied(to: videos[i])
        do { try save() } catch { errorMessage = "Enregistrement impossible : \(error)" }
    }

    // MARK: - Tags et étiquettes Finder

    func toggle(_ tag: TagDef) {
        guard isLoaded, !tagsLocked, let i = videos.firstIndex(where: { $0.id == selectedID }) else { return }
        if videos[i].tags[tag.key] == true {
            videos[i].tags[tag.key] = nil
        } else {
            videos[i].tags[tag.key] = true
        }
        do {
            try save()
            try syncFinderTags(videos[i], managed: config.tags.compactMap(\.finder))
        } catch {
            errorMessage = "Enregistrement impossible : \(error)"
        }
    }

    private func activeFinderTags(_ v: Video) -> [FinderTag] {
        config.tags.compactMap { v.tags[$0.key] == true ? $0.finder : nil }
    }

    private func syncFinderTags(_ v: Video, managed: [FinderTag]) throws {
        guard let root else { return }
        try FinderTags.sync(root.appendingPathComponent(v.path), managed: managed, active: activeFinderTags(v))
    }

    /// Réapplique les étiquettes de toutes les vidéos qui ont au moins un tag coché.
    /// `previous` = anciens tags, pour retirer les étiquettes renommées ou supprimées.
    func resyncAllTags(previous: [TagDef]? = nil, announce: Bool = true) {
        guard isLoaded else { return }
        let managed = Array(Set((previous ?? []).compactMap(\.finder) + config.tags.compactMap(\.finder)))
        let targets = videos.filter { $0.tags.values.contains(true) }
        var failures = 0
        for v in targets {
            do { try syncFinderTags(v, managed: managed) } catch { failures += 1 }
        }
        if failures > 0 {
            errorMessage = "\(failures) fichier(s) n'ont pas pu recevoir leurs étiquettes (introuvables ?)"
        } else if announce {
            notice = "Étiquettes Finder réappliquées sur \(targets.count) vidéo(s)."
        }
    }

    // MARK: - Navigation

    func select(offset: Int) {
        let list = filtered
        guard !list.isEmpty else { return }
        guard let i = list.firstIndex(where: { $0.id == selectedID }) else {
            selectedID = list.first?.id
            return
        }
        markReviewed(selectedID)
        selectedID = list[min(max(i + offset, 0), list.count - 1)].id
    }

    func next() { select(offset: 1) }
    func previous() { select(offset: -1) }

    func nextUnreviewed() {
        markReviewed(selectedID)
        let list = filtered
        let start = list.firstIndex { $0.id == selectedID }.map { $0 + 1 } ?? 0
        let ordered = Array(list[start...]) + Array(list[..<start])
        if let target = ordered.first(where: { !$0.reviewed }) { selectedID = target.id }
    }

    private func markReviewed(_ id: String?) {
        guard isLoaded, let i = videos.firstIndex(where: { $0.id == id }), !videos[i].reviewed else { return }
        videos[i].reviewed = true
        do { try save() } catch { errorMessage = "Enregistrement impossible : \(error)" }
    }
}
