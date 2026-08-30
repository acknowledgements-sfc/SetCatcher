import Foundation
import SetCatcherCore

/// Optional accounts HTTP client for SetCatcher on iPad. Local library never depends on this.
/// Uses the same Vercel/Clerk/Supabase stack for **accounts only** — not archives or Capture.
enum CompanionAccountClient {
    enum ClientError: LocalizedError {
        case notConfigured
        case unauthorized
        case server(String)
        case decoding

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Account API URL is not configured."
            case .unauthorized: return "Sign in again to use account features."
            case .server(let message): return message
            case .decoding: return "Could not read the account server response."
            }
        }
    }

    struct LicenseResponse: Decodable, Sendable {
        struct UserInfo: Decodable, Sendable {
            let id: String
            let email: String
            let displayName: String?
            let status: String
            let releaseChannel: String
        }

        struct LicenseInfo: Decodable, Sendable {
            let id: String?
            let plan: String
            let status: String
            let renewsOrExpiresAt: String?
        }

        struct LocalFeatures: Decodable, Sendable {
            let archiveScanProtect: Bool
            let note: String
        }

        let user: UserInfo
        let license: LicenseInfo
        let localFeatures: LocalFeatures
    }

    struct DeviceResponse: Decodable, Sendable {
        struct Device: Decodable, Sendable {
            let id: String
        }

        let device: Device
        let created: Bool
    }

    static var baseURLString: String {
        SetCatcherAccountConfiguration.baseURLString
    }

    static func fetchLicense(bearerToken: String) async throws -> LicenseResponse {
        try await request(path: "/api/license", method: "GET", bearerToken: bearerToken, body: nil)
    }

    static func registerDevice(
        bearerToken: String,
        deviceName: String,
        appVersion: String?,
        installChannel: String,
        platformDeviceId: String
    ) async throws -> DeviceResponse {
        struct Body: Encodable {
            let deviceName: String
            let appVersion: String?
            let installChannel: String
            let platformDeviceId: String
        }
        let data = try JSONEncoder().encode(
            Body(
                deviceName: deviceName,
                appVersion: appVersion,
                installChannel: installChannel,
                platformDeviceId: platformDeviceId
            )
        )
        return try await request(path: "/api/devices", method: "POST", bearerToken: bearerToken, body: data)
    }

    private static func request<T: Decodable>(
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

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ClientError.decoding }
        if http.statusCode == 401 { throw ClientError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            if let obj = try? JSONDecoder().decode([String: String].self, from: data),
               let error = obj["error"] {
                throw ClientError.server(error)
            }
            throw ClientError.server("Account server returned \(http.statusCode).")
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw ClientError.decoding
        }
    }
}
