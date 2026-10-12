import Foundation
import Observation
import VideoTagCore

/// Lance `planche-contact.sh` (dépôt charlescoiffier/planche-contact) dossier par dossier
/// et expose la progression à l'interface.
@MainActor @Observable
final class PlancheRunner {
    enum Phase: Equatable { case idle, running, finished, failed(String) }

    var phase: Phase = .idle
    var folders: [String] = []
    var folderIndex = 0
    var current = ""
    var log: [String] = []
    var created = 0
    var skipped = 0
    var failed = 0
    private var process: Process?
    private var cancelled = false

    var isRunning: Bool { phase == .running }

    static func scriptURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "planche-contact", withExtension: "sh") { return bundled }
        let dev = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Developer/planche-contact/planche-contact.sh")
        return FileManager.default.fileExists(atPath: dev.path) ? dev : nil
    }

    static func toolsPath() -> String? {
        ["/opt/homebrew/bin", "/usr/local/bin"].first {
            FileManager.default.isExecutableFile(atPath: "\($0)/ffmpeg")
                && FileManager.default.isExecutableFile(atPath: "\($0)/ffprobe")
        }
    }

    func cancel() {
        cancelled = true
        process?.terminate()
    }

    func run(root: URL, folders: [String], settings: PlancheSettings) async {
        guard let script = Self.scriptURL() else { phase = .failed("Script planche-contact.sh introuvable."); return }
        guard let tools = Self.toolsPath() else {
            phase = .failed("ffmpeg est introuvable. Installez-le avec : brew install ffmpeg")
            return
        }
        self.folders = folders
        folderIndex = 0
        created = 0; skipped = 0; failed = 0
        log = []
        cancelled = false
        phase = .running
        let args = PlancheContact.arguments(settings: settings, screenDir: root.appendingPathComponent(settings.folder))

        for (i, folder) in folders.enumerated() {
            if cancelled { break }
            folderIndex = i + 1
            current = folder
            await runOne(script: script, args: args, cwd: root.appendingPathComponent(folder), tools: tools)
        }
        phase = .finished
    }

    private func runOne(script: URL, args: [String], cwd: URL, tools: String) async {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/bash")
        p.arguments = [script.path] + args
        p.currentDirectoryURL = cwd
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "\(tools):" + (env["PATH"] ?? "/usr/bin:/bin")
        p.environment = env
        p.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = pipe
        process = p

        let stream = AsyncStream<String> { continuation in
            var buffer = Data()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let chunk = handle.availableData
                if chunk.isEmpty {
                    pipe.fileHandleForReading.readabilityHandler = nil
                    if !buffer.isEmpty, let s = String(data: buffer, encoding: .utf8) { continuation.yield(s) }
                    continuation.finish()
                    return
                }
                buffer.append(chunk)
                while let nl = buffer.firstIndex(of: 0x0A) {
                    let line = buffer[buffer.startIndex..<nl]
                    buffer.removeSubrange(buffer.startIndex...nl)
                    if let s = String(data: line, encoding: .utf8) { continuation.yield(s) }
                }
            }
        }
        do { try p.run() } catch {
            failed += 1
            append("Impossible de lancer le script : \(error.localizedDescription)")
            return
        }
        for await line in stream { handle(line) }
        p.waitUntilExit()
        process = nil
    }

    private func handle(_ line: String) {
        if line.hasPrefix("  ✓") { created += 1 }
        else if line.hasPrefix("  =") { skipped += 1 }
        else if line.hasPrefix("  !") {
            // Les fichiers « ._* » (métadonnées macOS sur disque exFAT) ne sont pas de vraies vidéos.
            if !line.contains("/._") { failed += 1 }
            else { return }
        }
        else if line.hasPrefix("[") { current = String(line.drop { $0 != " " }.dropFirst()) }
        else if line.isEmpty || line.hasPrefix("Recherche") || line.hasPrefix("Terminé") { return }
        append(line)
    }

    private func append(_ line: String) {
        log.append(line)
        if log.count > 300 { log.removeFirst(log.count - 300) }
    }
}
