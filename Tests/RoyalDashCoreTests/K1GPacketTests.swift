import XCTest
@testable import RoyalDashCore

final class K1GPacketTests: XCTestCase {
    func testBuildsButtonAckPacket() {
        let packet = DashCommands.buttonAck(0x06)

        XCTAssertEqual(packet.hexString(separator: ""), "0016000200000000020100054B314720000680000106")
    }

    func testPatchesRollingSequenceAfterMagic() {
        let packet = DashCommands.buttonAck(0x22)
        let patched = K1GPacket.patchSequence(packet, sequence: 0x7A)

        XCTAssertEqual(patched[16], 0x7A)
        XCTAssertEqual(patched[0], 0x00)
        XCTAssertEqual(patched[1], UInt8(patched.count))
    }

    func testParsesIncomingShortHeaderTlvs() {
        let incoming: [UInt8] = [
            0x00, 0x0D, 0x00, 0x01,
            0x00, 0x00, 0x00, 0x00,
            0x09, 0x06, 0x00, 0x01, 0x55,
        ]

        XCTAssertEqual(K1GPacket.parseIncoming(incoming), [
            Tlv(type: 0x09, sub: 0x06, value: [0x55]),
        ])
    }
}
