import Foundation

public enum ArchiveCatalogPlatform: String, Codable, Equatable, Sendable {
    case macos
    case ios
}

public enum ArchiveCatalogAvailability: Equatable, Sendable {
  case localFile
  case remoteOnly(originDeviceName: String?)
  case localAndSynced
}

public struct ArchiveCatalogSetContextDTO: Codable, Equatable, Sendable {
    public var eventName: String
    public var venue: String
    public var city: String
    public var tags: String
    public var updatedAt: Date?

    public init(
        eventName: String = "",
        venue: String = "",
        city: String = "",
        tags: String = "",
        updatedAt: Date? = nil
    ) {
        self.eventName = eventName
        self.venue = venue
        self.city = city
        self.tags = tags
        self.updatedAt = updatedAt
    }
}

public struct ArchiveCatalogSessionDTO: Codable, Equatable, Sendable, Identifiable {
    public var sessionId: UUID
    public var platform: ArchiveCatalogPlatform
    public var originDeviceId: UUID?
    public var originDeviceName: String?
    public var sourceAppId: String
    public var detectedAt: Date
    public var completedAt: Date?
    public var originalFilename: String
    public var fileSize: Int64
    public var durationSeconds: Double?
    public var ingestionKind: ArchiveIngestionKind?
    public var companionAppId: String?
    public var captureRoute: CaptureArchiveRoute?
    public var captureBackend: CaptureArchiveBackend?
    public var captureDeviceName: String?
    public var captureDeviceTransport: String?
    public var captureInterrupted: Bool
    public var captureInterruptionReason: String?
    public var audioBackedUp: Bool
    public var updatedAt: Date?
    public var setContext: ArchiveCatalogSetContextDTO?

    public var id: UUID { sessionId }

    enum CodingKeys: String, CodingKey {
        case sessionId
        case platform
        case originDeviceId
        case originDeviceName
        case sourceAppId
        case detectedAt
        case completedAt
        case originalFilename
        case fileSize
        case durationSeconds
        case ingestionKind
        case companionAppId
        case captureRoute
        case captureBackend
        case captureDeviceName
        case captureDeviceTransport
        case captureInterrupted
        case captureInterruptionReason
        case audioBackedUp
        case updatedAt
        case setContext
    }
}

public struct ArchiveCatalogPushRequest: Encodable, Sendable {
    public let sessions: [ArchiveCatalogSessionDTO]

    public init(sessions: [ArchiveCatalogSessionDTO]) {
        self.sessions = sessions
    }
}

public struct ArchiveCatalogPullResponse: Decodable, Sendable {
    public struct Restrictions: Decodable, Sendable {
        public let audio: Bool
        public let tracklistContents: Bool
        public let note: String?
    }

    public let sessions: [ArchiveCatalogSessionDTO]
    public let restrictions: Restrictions?
}

public struct ArchiveCatalogPushResponse: Decodable, Sendable {
    public let upserted: [String]
    public let count: Int
}

public enum ArchiveCatalogMapper {
    public static func dto(
        from archive: ArchiveMetadata,
        context: SetContext?,
        platform: ArchiveCatalogPlatform,
        originDeviceName: String?,
        audioBackedUp: Bool = false
    ) -> ArchiveCatalogSessionDTO {
        ArchiveCatalogSessionDTO(
            sessionId: archive.sessionID,
            platform: platform,
            originDeviceId: nil,
            originDeviceName: originDeviceName,
            sourceAppId: archive.sourceAppID,
            detectedAt: archive.detectedAt,
            completedAt: archive.completedAt,
            originalFilename: archive.originalFilename,
            fileSize: archive.fileSize,
            durationSeconds: archive.durationSeconds,
            ingestionKind: archive.ingestionKind,
            companionAppId: archive.companionAppID,
            captureRoute: archive.captureRoute,
            captureBackend: archive.captureBackend,
            captureDeviceName: archive.captureDeviceName,
            captureDeviceTransport: archive.captureDeviceTransport,
            captureInterrupted: archive.captureInterrupted,
            captureInterruptionReason: archive.captureInterruptionReason,
            audioBackedUp: audioBackedUp,
            updatedAt: Date(),
            setContext: context.map(contextDTO(from:))
        )
    }

    public static func contextDTO(from context: SetContext) -> ArchiveCatalogSetContextDTO {
        ArchiveCatalogSetContextDTO(
            eventName: context.eventName,
            venue: context.venue,
            city: context.city,
            tags: context.tags,
            updatedAt: context.updatedAt
        )
    }

    public static func setContext(from dto: ArchiveCatalogSetContextDTO, sessionID: UUID) -> SetContext {
        mergingSyncedFields(from: dto, into: nil, sessionID: sessionID)
    }

    public static func mergingSyncedFields(
        from dto: ArchiveCatalogSetContextDTO,
        into localContext: SetContext?,
        sessionID: UUID
    ) -> SetContext {
        SetContext(
            sessionID: sessionID,
            eventName: dto.eventName,
            venue: dto.venue,
            city: dto.city,
            tags: dto.tags,
            notes: localContext?.notes ?? "",
            manualTracklistID: localContext?.manualTracklistID,
            updatedAt: dto.updatedAt ?? Date()
        )
    }

    public static func stubArchive(from dto: ArchiveCatalogSessionDTO) -> ArchiveMetadata {
        ArchiveMetadata(
            sessionID: dto.sessionId,
            sourceAppID: dto.sourceAppId,
            detectedAt: dto.detectedAt,
            completedAt: dto.completedAt,
            sourcePath: "",
            archivePath: "",
            fileSize: dto.fileSize,
            originalFilename: dto.originalFilename,
            durationSeconds: dto.durationSeconds,
            sourceFingerprint: nil,
            ingestionKind: dto.ingestionKind,
            companionAppID: dto.companionAppId,
            captureRoute: dto.captureRoute,
            captureBackend: dto.captureBackend,
            captureDeviceUID: nil,
            captureDeviceName: dto.captureDeviceName,
            captureDeviceTransport: dto.captureDeviceTransport,
            captureInterrupted: dto.captureInterrupted,
            captureInterruptionReason: dto.captureInterruptionReason
        )
    }
}

public struct ArchiveCatalogMerger {
    public init() {}

    public func mergedArchives(
        localArchives: [ArchiveMetadata],
        remoteSessions: [ArchiveCatalogSessionDTO]
    ) -> [ArchiveMetadata] {
        let localIDs = Set(localArchives.map(\.sessionID))
        let remoteStubs = remoteSessions
            .filter { !localIDs.contains($0.sessionId) }
            .map(ArchiveCatalogMapper.stubArchive(from:))
        return (localArchives + remoteStubs).sorted { $0.detectedAt > $1.detectedAt }
    }

    public func mergedSetContexts(
        localContexts: [SetContext],
        remoteSessions: [ArchiveCatalogSessionDTO],
        localArchiveIDs: Set<UUID>
    ) -> [SetContext] {
        var merged = Dictionary(uniqueKeysWithValues: localContexts.map { ($0.sessionID, $0) })
        for remote in remoteSessions {
            guard let remoteContext = remote.setContext else { continue }
            let sessionID = remote.sessionId
            let incoming = ArchiveCatalogMapper.setContext(from: remoteContext, sessionID: sessionID)
            if let existing = merged[sessionID] {
                if incoming.updatedAt > existing.updatedAt {
                    merged[sessionID] = ArchiveCatalogMapper.mergingSyncedFields(
                        from: remoteContext,
                        into: existing,
                        sessionID: sessionID
                    )
                }
            } else if !localArchiveIDs.contains(sessionID) {
                merged[sessionID] = incoming
            }
        }
        return Array(merged.values)
    }

    public func catalogAvailability(
        for sessionID: UUID,
        hasLocalFile: Bool,
        remoteSessions: [ArchiveCatalogSessionDTO]
    ) -> ArchiveCatalogAvailability {
        guard remoteSessions.contains(where: { $0.sessionId == sessionID }) else {
            return .localFile
        }
        if hasLocalFile {
            return .localAndSynced
        }
        let remote = remoteSessions.first { $0.sessionId == sessionID }
        return .remoteOnly(originDeviceName: remote?.originDeviceName)
    }
}

public struct ArchiveCatalogHTTPClient: Sendable {
    public enum ClientError: Error, Equatable, Sendable {
        case notConfigured
        case unauthorized
        case server(String)
        case decoding
    }

    public let baseURLString: String
  private let session: URLSession
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

    public init(
        baseURLString: String = SetCatcherAccountConfiguration.baseURLString,
        session: URLSession = .shared
    ) {
        self.baseURLString = baseURLString
        self.session = session
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func pullSessions(
        bearerToken: String,
        updatedSince: Date? = nil
    ) async throws -> ArchiveCatalogPullResponse {
        var path = "/api/archive/sessions"
        if let updatedSince {
            let iso = ISO8601DateFormatter().string(from: updatedSince)
            path += "?updatedSince=\(iso.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? iso)"
        }
        return try await request(path: path, method: "GET", bearerToken: bearerToken, body: nil)
    }

    public func pushSessions(
        bearerToken: String,
        sessions: [ArchiveCatalogSessionDTO]
    ) async throws -> ArchiveCatalogPushResponse {
        let body = try encoder.encode(ArchiveCatalogPushRequest(sessions: sessions))
        return try await request(path: "/api/archive/sessions", method: "POST", bearerToken: bearerToken, body: body)
    }

    public func deleteSession(bearerToken: String, sessionID: UUID) async throws {
        struct DeleteResponse: Decodable {
            let deleted: Bool
        }
        let _: DeleteResponse = try await request(
            path: "/api/archive/sessions/\(sessionID.uuidString)",
            method: "DELETE",
            bearerToken: bearerToken,
            body: nil
        )
    }

    private func request<T: Decodable>(
        path: String,
        method: String,
        bearerToken: String,
        body: Data?
    ) async throws -> T {
        let normalized = path.hasPrefix("/") ? path : "/\(path)"
        let trimmedBase = baseURLString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: trimmedBase + normalized) else {
            throw ClientError.notConfigured
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClientError.decoding
        }
        if http.statusCode == 401 {
            throw ClientError.unauthorized
        }
        guard (200..<300).contains(http.statusCode) else {
            if let obj = try? decoder.decode([String: String].self, from: data),
               let error = obj["error"] {
                throw ClientError.server(error)
            }
            throw ClientError.server("Account server returned \(http.statusCode).")
        }
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw ClientError.decoding
        }
    }
}
