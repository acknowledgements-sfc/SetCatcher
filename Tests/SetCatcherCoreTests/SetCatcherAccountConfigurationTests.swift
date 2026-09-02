import XCTest
@testable import SetCatcherCore

final class SetCatcherAccountConfigurationTests: XCTestCase {
    func testDefaultAccountBaseURLIsProductionHost() {
        XCTAssertEqual(SetCatcherAccountConfiguration.baseURLString, "https://beatrevival.com")
    }

    func testClerkPublishableKeyIsOptionalByDefault() {
        XCTAssertNil(SetCatcherAccountConfiguration.clerkPublishableKey)
    }

    func testClerkKeyIgnoresEmptyAndUnexpandedPlistPlaceholders() {
        XCTAssertNil(SetCatcherAccountConfiguration.normalized(nil))
        XCTAssertNil(SetCatcherAccountConfiguration.normalized("   "))
        XCTAssertNil(SetCatcherAccountConfiguration.normalized("$(SETCATCHER_CLERK_PUBLISHABLE_KEY)"))
        XCTAssertEqual(SetCatcherAccountConfiguration.normalized(" pk_test_abc "), "pk_test_abc")
    }
}
