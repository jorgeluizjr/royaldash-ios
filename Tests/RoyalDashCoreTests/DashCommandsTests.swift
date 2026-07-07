import XCTest
@testable import RoyalDashCore

final class DashCommandsTests: XCTestCase {
    func testAuthRequestMatchesFrozenOpenDashBytes() {
        XCTAssertEqual(
            DashCommands.authRequest().hexString(separator: ""),
            "0016000200000000020100054B314720000804000101"
        )
    }

    func testAuthSendKeyRequiresRsa1024Ciphertext() {
        XCTAssertThrowsError(try DashCommands.authSendKey(ciphertext: [0x00])) { error in
            XCTAssertEqual(error as? DashCommandError, .invalidCiphertextLength(1))
        }
    }

    func testAuthSendKeyWrapsCiphertext() throws {
        let ciphertext = [UInt8](repeating: 0xAB, count: 128)
        let packet = try DashCommands.authSendKey(ciphertext: ciphertext)

        XCTAssertEqual(packet.count, 149)
        XCTAssertEqual(packet.prefix(21).map { $0 }.hexString(separator: ""), "0095000200000000020100054B3147200008000080")
        XCTAssertEqual(packet.suffix(128).map { $0 }, ciphertext)
    }
}
