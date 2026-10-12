import Foundation

/// Réglages des planches de captures : les mêmes que ceux du script `planche-contact`
/// (hors extensions vidéo et emplacement, que l'application impose : un dossier plat à la racine).
public struct PlancheSettings: Codable, Equatable, Sendable {
    /// Nombre de captures par vidéo (1 à 500).
    public var captures = 9
    /// Colonnes du damier (1 à 50).
    public var columns = 3
    /// Largeur d'une capture en pixels (100 à 4000).
    public var thumbnailWidth = 480
    /// Marge entre les images en pixels (0 à 200).
    public var innerMargin = 6
    /// Marge autour du damier en pixels (0 à 200).
    public var outerMargin = 6
    /// Couleur de fond : nom ffmpeg ou `0xRRGGBB`.
    public var background = "black"
    /// `jpg` ou `png`.
    public var format = "jpg"
    /// Qualité JPEG en % (1 à 100).
    public var quality = 95
    /// Texte ajouté avant le nom de la vidéo.
    public var prefix = ""
    /// Texte ajouté après le nom de la vidéo (avant l'extension).
    public var suffix = ""
    /// Remplacer une planche déjà existante.
    public var overwrite = false
    /// Nom du dossier des planches, à la racine du dossier analysé.
    public var folder = "screen"

    public init() {}

    enum CodingKeys: String, CodingKey {
        case captures, columns, thumbnailWidth, innerMargin, outerMargin, background
        case format, quality, prefix, suffix, overwrite, folder
    }

    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        captures = try c.decodeIfPresent(Int.self, forKey: .captures) ?? captures
        columns = try c.decodeIfPresent(Int.self, forKey: .columns) ?? columns
        thumbnailWidth = try c.decodeIfPresent(Int.self, forKey: .thumbnailWidth) ?? thumbnailWidth
        innerMargin = try c.decodeIfPresent(Int.self, forKey: .innerMargin) ?? innerMargin
        outerMargin = try c.decodeIfPresent(Int.self, forKey: .outerMargin) ?? outerMargin
        background = try c.decodeIfPresent(String.self, forKey: .background) ?? background
        format = try c.decodeIfPresent(String.self, forKey: .format) ?? format
        quality = try c.decodeIfPresent(Int.self, forKey: .quality) ?? quality
        prefix = try c.decodeIfPresent(String.self, forKey: .prefix) ?? prefix
        suffix = try c.decodeIfPresent(String.self, forKey: .suffix) ?? suffix
        overwrite = try c.decodeIfPresent(Bool.self, forKey: .overwrite) ?? overwrite
        folder = try c.decodeIfPresent(String.self, forKey: .folder) ?? folder
    }

    /// Valeurs par défaut du script `planche-contact` (le dossier reste celui de l'application).
    public static var scriptDefaults: PlancheSettings {
        var s = PlancheSettings()
        s.captures = 12
        s.columns = 4
        s.prefix = "planche_"
        return s
    }

    /// Nom du fichier de planche d'une vidéo (sans le dossier).
    public func fileName(forStem stem: String) -> String {
        "\(prefix)\(stem)\(suffix).\(format)"
    }

    public var validationErrors: [String] {
        var errors: [String] = []
        func check(_ value: Int, _ label: String, _ range: ClosedRange<Int>) {
            if !range.contains(value) { errors.append("\(label) : valeur attendue entre \(range.lowerBound) et \(range.upperBound).") }
        }
        check(captures, "Nombre de captures", 1...500)
        check(columns, "Colonnes", 1...50)
        check(thumbnailWidth, "Largeur d'une capture", 100...4000)
        check(innerMargin, "Marge entre les images", 0...200)
        check(outerMargin, "Marge autour du damier", 0...200)
        check(quality, "Qualité JPEG", 1...100)
        if background.trimmingCharacters(in: .whitespaces).isEmpty { errors.append("Couleur de fond : la valeur ne peut pas être vide.") }
        if !["jpg", "png"].contains(format) { errors.append("Format : jpg ou png.") }
        if prefix.contains("/") { errors.append("Préfixe : « / » interdit.") }
        if suffix.contains("/") { errors.append("Suffixe : « / » interdit.") }
        let f = folder.trimmingCharacters(in: .whitespaces)
        if f.isEmpty || f.contains("/") || f.hasPrefix(".") {
            errors.append("Dossier des planches : un simple nom, sans « / » et sans point au début.")
        }
        return errors
    }
}
