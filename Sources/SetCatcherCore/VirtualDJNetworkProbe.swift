import Foundation

public struct VirtualDJNetworkProbeResult: Equatable, Sendable {
    public let endpoint: URL
    public let reachable: Bool
    public let statusCode: Int?
    public let errorDescription: String?

    public init(endpoint: URL, reachable: Bool, statusCode: Int?, errorDescription: String?) {
        self.endpoint = endpoint
        self.reachable = reachable
        self.statusCode = statusCode
        self.errorDescription = errorDescription
    }
}

public final class VirtualDJNetworkProbe: @unchecked Sendable {
    public static let defaultEndpoint = URL(string: "http://127.0.0.1:8080/")!

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func probe(
        endpoint: URL = VirtualDJNetworkProbe.defaultEndpoint,
        timeoutSeconds: TimeInterval = 2
    ) async -> VirtualDJNetworkProbeResult {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = timeoutSeconds

        do {
            let (_, response) = try await session.data(for: request)
            let statusCode = (response as? HTTPURLResponse)?.statusCode

            return VirtualDJNetworkProbeResult(
                endpoint: endpoint,
                reachable: true,
                statusCode: statusCode,
                errorDescription: nil
            )
        } catch {
            return VirtualDJNetworkProbeResult(
                endpoint: endpoint,
                reachable: false,
                statusCode: nil,
                errorDescription: error.localizedDescription
            )
        }
    }
}
