import Foundation

/// Appel du script `planche-contact.sh` avec les réglages de l'utilisateur ; les planches sont rangées à plat
/// dans le dossier des planches, nommées comme la vidéo.
public enum PlancheContact {
    /// À lancer depuis le dossier de la vidéo : `-O ailleurs` écrit alors directement `screenDir/<nom>.<format>`.
    public static func arguments(settings s: PlancheSettings, screenDir: URL) -> [String] {
        var args = ["-n", "\(s.captures)", "-c", "\(s.columns)", "-w", "\(s.thumbnailWidth)",
                    "-m", "\(s.innerMargin)", "-M", "\(s.outerMargin)", "-b", s.background,
                    "-f", s.format, "-q", "\(s.quality)", "-p", s.prefix, "-s", s.suffix,
                    "-O", "ailleurs", "-o", screenDir.path]
        if s.overwrite { args.append("-F") }
        args.append("-y")
        return args
    }

    /// Dossiers parents (triés, `""` = racine) qui contiennent au moins une vidéo sans planche.
    public static func foldersToProcess(videos: [Video]) -> [String] {
        Array(Set(videos.filter { $0.screen == nil }.map(\.folder))).sorted()
    }

    public static func missingCount(videos: [Video]) -> Int {
        videos.filter { $0.screen == nil }.count
    }
}
