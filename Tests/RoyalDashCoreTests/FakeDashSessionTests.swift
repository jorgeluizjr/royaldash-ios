import XCTest
@testable import RoyalDashCore

final class FakeDashSessionTests: XCTestCase {
    func testAuthRequestReturnsPublicKeyPackets() {
        var dash = FakeDashSession()

        let result = dash.receiveControl(DashCommands.authRequest())

        XCTAssertEqual(dash.state, .publicKeyOffered)
        XCTAssertTrue(result.events.contains(.authRequestReceived))
        XCTAssertEqual(result.packets.count, 2)
        XCTAssertEqual(K1GPacket.parseIncoming(result.packets[0]), [
            Tlv(type: 0x07, sub: 0x00, value: FakeDashSession.defaultModulus),
        ])
        XCTAssertEqual(K1GPacket.parseIncoming(result.packets[1]), [
            Tlv(type: 0x07, sub: 0x03, value: [0x01, 0x00, 0x01]),
        ])
    }

    func testAuthSendKeyConfirmsOnly128ByteCiphertext() throws {
        var dash = FakeDashSession()
        let keyPacket = try DashCommands.authSendKey(ciphertext: Array(repeating: 0x42, count: 128))

        let result = dash.receiveControl(keyPacket)

        XCTAssertEqual(dash.state, .authenticated)
        XCTAssertTrue(result.events.contains(.authKeyReceived(ciphertextLength: 128)))
        XCTAssertEqual(K1GPacket.parseIncoming(result.packets[0]), [
            Tlv(type: 0x07, sub: 0x01, value: [0x01]),
        ])
    }

    func testInvalidAuthKeyIsRejected() {
        var dash = FakeDashSession()
        let invalidPacket = K1GPacket.build([Tlv(type: 0x08, sub: 0x00, value: [0x42])])

        let result = dash.receiveControl(invalidPacket)

        XCTAssertTrue(result.events.contains(.authRejected(reason: "Expected 128-byte q3c.d ciphertext, got 1.")))
        XCTAssertEqual(K1GPacket.parseIncoming(result.packets[0]), [
            Tlv(type: 0x07, sub: 0x01, value: [0x00]),
        ])
    }

    func testFrameAndButtonNotificationsMatchDashToAppTlvs() {
        let dash = FakeDashSession()

        XCTAssertEqual(K1GPacket.parseIncoming(dash.frameDecodedNotify(kind: .idr)), [
            Tlv(type: 0x09, sub: 0x06, value: [0x55]),
        ])
        XCTAssertEqual(K1GPacket.parseIncoming(dash.frameDecodedNotify(kind: .predicted)), [
            Tlv(type: 0x09, sub: 0x04, value: [0x55]),
        ])
        XCTAssertEqual(K1GPacket.parseIncoming(dash.buttonEvent(code: 0x06)), [
            Tlv(type: 0x09, sub: 0x00, value: [0x00, 0x01, 0x06]),
        ])
    }

    func testRtpPacketObservationExtractsHeaderFields() {
        var packets: [[UInt8]] = []
        var packetizer = RtpPacketizer(
            initialSequence: 0x0102,
            ssrc: 0x11223344,
            timestampBase: 0,
            onPacket: { packets.append($0) }
        )
        packetizer.packetize(nal: [0x65, 0x01, 0x02], endOfAccessUnit: true, wallClockMs: 10)

        let dash = FakeDashSession()
        let result = dash.receiveRtp(packets[0])

        XCTAssertEqual(result.events, [
            .rtpPacketReceived(sequence: 0x0102, timestamp: 900, marker: true, payloadBytes: 3),
        ])
    }
}
