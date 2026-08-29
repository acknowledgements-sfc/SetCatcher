import Foundation

public enum PublishExportError: Error, Equatable, Sendable {
    case archiveMissing
    case destinationUnavailable
    case writeFailed(String)
}

public struct PublishExportService {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    @discardableResult
    public func exportPack(archive: ArchiveMetadata, tracklist: ImportedTracklist?, destinationDirectory: URL) throws -> URL {
        var isDirectory: ObjCBool = false
        let archiveURL = URL(fileURLWithPath: archive.archivePath)
        guard fileManager.fileExists(atPath: archiveURL.path, isDirectory: &isDirectory), !isDirectory.boolValue else {
            throw PublishExportError.archiveMissing
        }
        try fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        guard fileManager.fileExists(atPath: destinationDirectory.path) else {
            throw PublishExportError.destinationUnavailable
        }
        let invalid = CharacterSet(charactersIn: "/:")
        let packName = "\(archive.originalFilename)-publish".components(separatedBy: invalid).joined(separator: "-")
        let packDirectory = destinationDirectory.appendingPathComponent(packName, isDirectory: true)
        if fileManager.fileExists(atPath: packDirectory.path) {
            try fileManager.removeItem(at: packDirectory)
        }
        try fileManager.createDirectory(at: packDirectory, withIntermediateDirectories: true)
        do {
            try fileManager.copyItem(at: archiveURL, to: packDirectory.appendingPathComponent(archiveURL.lastPathComponent))
        } catch {
            throw PublishExportError.writeFailed(error.localizedDescription)
        }
        if let tracklist {
            let lines = tracklist.tracks.enumerated().map { index, play in
                let artist = play.artist.isEmpty ? "Unknown Artist" : play.artist
                let title = play.title.isEmpty ? "Unknown Title" : play.title
                return "\(index + 1). \(artist) - \(title)"
            }
            let body = (["SetCatcher tracklist export", "Source: \(tracklist.sourceURL.lastPathComponent)", ""] + lines).joined(separator: "\n")
            do {
                try Data(body.utf8).write(to: packDirectory.appendingPathComponent("tracklist.txt"), options: [.atomic])
            } catch {
                throw PublishExportError.writeFailed(error.localizedDescription)
            }
        }
        return packDirectory
    }
}
