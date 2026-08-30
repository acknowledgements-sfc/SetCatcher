import Foundation

public enum VirtualDJNetworkCommand: String, CaseIterable, Sendable {
    case root = "/"
    case getText = "get_text"
    case getDeck = "deck"

    public var pathComponent: String? {
        switch self {
        case .root: return nil
        case .getText, .getDeck: return rawValue
        }
    }
}

public struct VirtualDJNetworkCommandResult: Equatable, Sendable {
    public let endpoint: URL
    public let command: VirtualDJNetworkCommand
    public let reachable: Bool
    public let statusCode: Int?
    public let bodyPreview: String?
    public let errorDescription: String?

    public init(endpoint: URL, command: VirtualDJNetworkCommand, reachable: Bool, statusCode: Int?, bodyPreview: String?, errorDescription: String?) {
        self.endpoint = endpoint
        self.command = command
        self.reachable = reachable
        self.statusCode = statusCode
        self.bodyPreview = bodyPreview
        self.errorDescription = errorDescription
    }
}

public final class VirtualDJNetworkClient: @unchecked Sendable {
    public static let defaultBaseURL = URL(string: "http://127.0.0.1:8080/")!
    private let session: URLSession
    public init(session: URLSession = .shared) { self.session = session }

    public func run(command: VirtualDJNetworkCommand, baseURL: URL = VirtualDJNetworkClient.defaultBaseURL, timeoutSeconds: TimeInterval = 2) async -> VirtualDJNetworkCommandResult {
        let endpoint = command.pathComponent.map { baseURL.appendingPathComponent($0) } ?? baseURL
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = timeoutSeconds
        do {
            let (data, response) = try await session.data(for: request)
            return VirtualDJNetworkCommandResult(endpoint: endpoint, command: command, reachable: true, statusCode: (response as? HTTPURLResponse)?.statusCode, bodyPreview: String(data: data.prefix(512), encoding: .utf8), errorDescription: nil)
        } catch {
            return VirtualDJNetworkCommandResult(endpoint: endpoint, command: command, reachable: false, statusCode: nil, bodyPreview: nil, errorDescription: error.localizedDescription)
        }
    }
}
