import XCTest
@testable import RoyalDashCore

final class RtpPacketizerTests: XCTestCase {
    func testPacketizesSmallNalAsSingleRtpPacket() {
        var packets: [[UInt8]] = []
        var packetizer = RtpPacketizer(
            initialSequence: 0x1234,
            ssrc: 0xAABBCCDD,
            timestampBase: 100,
            onPacket: { packets.append($0) }
        )

        packetizer.packetize(nal: [0x65, 0x01, 0x02], endOfAccessUnit: true, wallClockMs: 10)

        XCTAssertEqual(packets.count, 1)
        XCTAssertEqual(packets[0][0], 0x80)
        XCTAssertEqual(packets[0][1], 0xE0)
        XCTAssertEqual(packets[0][2], 0x12)
        XCTAssertEqual(packets[0][3], 0x34)
        XCTAssertEqual(Array(packets[0][4...7]), [0x00, 0x00, 0x03, 0xE8])
        XCTAssertEqual(Array(packets[0][8...11]), [0xAA, 0xBB, 0xCC, 0xDD])
        XCTAssertEqual(Array(packets[0].dropFirst(12)), [0x65, 0x01, 0x02])
    }

    func testFragmentsLargeNalWithFuAAndMarkerOnlyOnLastPacket() {
        var packets: [[UInt8]] = []
        var packetizer = RtpPacketizer(onPacket: { packets.append($0) })
        let nal = [0x65] + [UInt8](repeating: 0x44, count: RtpPacketizer.maxPayload + 50)

        packetizer.packetize(nal: nal, endOfAccessUnit: true, wallClockMs: 0)

        XCTAssertEqual(packets.count, 2)
        XCTAssertEqual(packets[0][1], 0x60)
        XCTAssertEqual(packets[1][1], 0xE0)
        XCTAssertEqual(packets[0][12], 0x7C)
        XCTAssertEqual(packets[0][13], 0x85)
        XCTAssertEqual(packets[1][12], 0x7C)
        XCTAssertEqual(packets[1][13], 0x45)
    }
}
