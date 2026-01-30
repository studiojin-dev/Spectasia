import XCTest
@testable import SpectasiaCore

final class SpectasiaCoreTests: XCTestCase {

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
    }

    func testCoreModuleExists() throws {
        // This is a "Hello World" test to verify the module is set up correctly
        XCTAssert(true, "SpectasiaCore module is accessible")
    }

    static let allTests = [
        ("testCoreModuleExists", testCoreModuleExists),
    ]
}
