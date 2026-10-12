import Foundation

/// Valeurs saisies dans la fenêtre « Informations de la vidéo ».
public struct VideoInfoDraft: Equatable, Sendable {
    public var title: String
    public var date: String
    public var author: String

    public init(title: String, date: String, author: String) {
        self.title = title; self.date = date; self.author = author
    }

    public init(video: Video) {
        self.init(title: video.title, date: video.date ?? "", author: video.author ?? "")
    }

    public var errors: [String] {
        var errors: [String] = []
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("Le titre est obligatoire.")
        }
        let d = date.trimmingCharacters(in: .whitespacesAndNewlines)
        if !d.isEmpty, !Self.isValidDate(d) {
            errors.append("La date doit être au format AAAA-MM-JJ (par exemple 2025-03-31).")
        }
        return errors
    }

    public func applied(to video: Video) -> Video {
        var v = video
        v.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let d = date.trimmingCharacters(in: .whitespacesAndNewlines)
        let a = author.trimmingCharacters(in: .whitespacesAndNewlines)
        v.date = d.isEmpty ? nil : d
        v.author = a.isEmpty ? nil : a
        return v
    }

    private static func isValidDate(_ s: String) -> Bool {
        guard s.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil else { return false }
        let parts = s.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return false }
        let calendar = Calendar(identifier: .gregorian)
        let components = DateComponents(year: parts[0], month: parts[1], day: parts[2])
        guard let date = calendar.date(from: components) else { return false }
        let back = calendar.dateComponents([.year, .month, .day], from: date)
        return back.year == parts[0] && back.month == parts[1] && back.day == parts[2]
    }
}
