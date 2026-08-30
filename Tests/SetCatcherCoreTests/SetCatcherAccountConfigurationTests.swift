import XCTest
@testable import SetCatcherCore

final class SetCatcherAccountConfigurationTests: XCTestCase {
    func testDefaultAccountBaseURLIsProductionHost() {
        XCTAssertEqual(SetCatcherAccountConfiguration.baseURLString, "https://beatrevival.com")
    }

    func testClerkPublishableKeyIsOptionalByDefault() {
        XCTAssertNil(SetCatcherAccountConfiguration.clerkPublishableKey)
    }
}
