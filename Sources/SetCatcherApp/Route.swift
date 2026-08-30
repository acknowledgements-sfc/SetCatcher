import Foundation

enum Route: Hashable {
    case home
    case protection
    case capture
    case library
    case activity
    case settings
    case app(String)
    case recovery(String)

    var appID: String? {
        switch self {
        case .app(let id), .recovery(let id):
            return id
        case .home, .protection, .capture, .library, .activity, .settings:
            return nil
        }
    }
}
