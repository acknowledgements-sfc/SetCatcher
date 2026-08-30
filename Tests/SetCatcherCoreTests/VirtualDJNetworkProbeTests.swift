import XCTest
@testable import SetCatcherCore

final class VirtualDJNetworkProbeTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.response = nil
        MockURLProtocol.error = nil
        super.tearDown()
    }

    func testProbeReportsReachableHTTPResponse() async throws {
        MockURLProtocol.response = HTTPURLResponse(
            url: VirtualDJNetworkProbe.defaultEndpoint,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        let probe = VirtualDJNetworkProbe(session: makeSession())

        let result = await probe.probe()

        XCTAssertTrue(result.reachable)
        XCTAssertEqual(result.statusCode, 200)
        XCTAssertNil(result.errorDescription)
    }

    func testProbeReportsNetworkError() async {
        MockURLProtocol.error = URLError(.cannotConnectToHost)
        let probe = VirtualDJNetworkProbe(session: makeSession())

        let result = await probe.probe()

        XCTAssertFalse(result.reachable)
        XCTAssertNil(result.statusCode)
        XCTAssertNotNil(result.errorDescription)
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}

private final class MockURLProtocol: URLProtocol {
    static var response: URLResponse?
    static var error: Error?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        if let error = Self.error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            let response = Self.response ?? HTTPURLResponse(
                url: request.url ?? VirtualDJNetworkProbe.defaultEndpoint,
                statusCode: 204,
                httpVersion: nil,
                headerFields: nil
            )!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data())
            client?.urlProtocolDidFinishLoading(self)
        }
    }

    override func stopLoading() {}
}
