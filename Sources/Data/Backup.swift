import Foundation
import SwiftUI
import UniformTypeIdentifiers

/// A runner's workout history as a file they keep, so it survives a reinstall or a new phone.
/// The Android app reads and writes the same format, so a history can also move between the two.
/// Times are milliseconds since the epoch. Settings aren't included.
struct Backup: Codable, Equatable {
    static let format = "c2k-backup"
    static let version = 1

    var format = Backup.format
    var version = Backup.version
    var exportedAt: Int64
    var sessions: [Session]

    struct Session: Codable, Equatable {
        var programId: String
        var week: Int
        var day: Int
        var startedAt: Int64
        var completedAt: Int64?
        var durationSeconds: Int
        var distanceMeters: Double
        var completed: Bool
        var route: [Point]
    }

    struct Point: Codable, Equatable {
        var latitude: Double
        var longitude: Double
        var altitudeMeters: Double?
        var speedMps: Double?
        var recordedAt: Int64
    }

    enum ReadError: Error, Equatable {
        /// Not JSON, not a C2K backup, or missing something a backup needs.
        case notABackup
        /// Written by a newer version of the app, in a format this one doesn't know.
        case newerVersion
    }

    init(exportedAt: Int64, sessions: [Session]) {
        self.exportedAt = exportedAt
        self.sessions = sessions
    }

    static func fileName(on date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "c2k-backup-\(formatter.string(from: date)).json"
    }

    static func decode(_ data: Data) throws -> Backup {
        struct Header: Decodable { let format: String?; let version: Int? }
        guard let header = try? JSONDecoder().decode(Header.self, from: data),
              header.format == format, let fileVersion = header.version, fileVersion >= 1
        else { throw ReadError.notABackup }
        guard fileVersion <= version else { throw ReadError.newerVersion }
        do {
            return try JSONDecoder().decode(Backup.self, from: data)
        } catch {
            throw ReadError.notABackup
        }
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }
}

extension Date {
    var millisecondsSince1970: Int64 { Int64((timeIntervalSince1970 * 1000).rounded()) }

    init(millisecondsSince1970 ms: Int64) {
        self.init(timeIntervalSince1970: Double(ms) / 1000)
    }
}

/// Hands a backup to the system's save dialog.
struct BackupDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.json]
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
