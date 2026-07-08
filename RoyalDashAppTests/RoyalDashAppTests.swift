import XCTest
@testable import RoyalDash

final class RoyalDashAppTests: XCTestCase {
    func testAppShellTestTargetRuns() {
        XCTAssertTrue(true)
    }

    @MainActor
    func testSimulatedConnectionModelExercisesCoreFlow() {
        let model = DashConnectionModel()
        XCTAssertEqual(model.mode, .simulated)

        model.advance()
        XCTAssertEqual(model.phase, .wifi)
        XCTAssertEqual(model.packetCount, 0)

        model.advance()
        XCTAssertEqual(model.phase, .authenticating)
        XCTAssertEqual(model.packetCount, 2)

        model.advance()
        XCTAssertEqual(model.phase, .streaming)
        XCTAssertEqual(model.packetCount, 4)

        model.advance()
        XCTAssertEqual(model.phase, .offline)
        XCTAssertEqual(model.packetCount, 0)
    }

    @MainActor
    func testConnectionModeSwitchResetsSessionState() {
        let model = DashConnectionModel()

        model.advance()
        XCTAssertEqual(model.phase, .wifi)

        model.setMode(.live)

        XCTAssertEqual(model.mode, .live)
        XCTAssertEqual(model.phase, .offline)
        XCTAssertEqual(model.packetCount, 0)
        XCTAssertEqual(model.controlStatus, "--")
        XCTAssertEqual(model.rtpStatus, "--")
    }
}
