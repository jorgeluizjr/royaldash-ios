import XCTest
@testable import RoyalDashCore

final class DashReceiveLoopTests: XCTestCase {
    func testFrameDecodedReplyIsSentThroughTransport() throws {
        let peer = RecordingDatagramPeer()
        let transport = DashTransport(
            config: .loopbackFakeDash,
            peer: peer,
            initialControlSequence: 0x10
        )
        var loop = DashReceiveLoop(
            dispatcher: DashIncomingDispatcher(auth: DashAuth(ssid: "RE_TEST")),
            transport: transport
        )
        var fakeDash = FakeDashSession()

        let events = try loop.handleIncomingDatagram(fakeDash.frameDecodedNotify(kind: .idr))

        XCTAssertEqual(events, [.frameDecoded(kind: .idr)])
        XCTAssertEqual(peer.sent.count, 1)
        XCTAssertEqual(peer.sent[0].endpoint, UdpEndpoint(host: "127.0.0.1", port: 2000))
        XCTAssertEqual(peer.sent[0].bytes[16], 0x10)
        XCTAssertEqual(K1GPacket.parseOutgoingControl(peer.sent[0].bytes), [
            Tlv(type: 0x06, sub: 0x11, value: [0x55]),
        ])
        XCTAssertEqual(loop.transport.nextControlSequence, 0x11)
    }

    func testButtonReplyIsSentAndEventReturned() throws {
        let peer = RecordingDatagramPeer()
        let transport = DashTransport(config: .loopbackFakeDash, peer: peer)
        var loop = DashReceiveLoop(
            dispatcher: DashIncomingDispatcher(auth: DashAuth(ssid: "RE_TEST")),
            transport: transport
        )
        let fakeDash = FakeDashSession()

        let events = try loop.handleIncomingDatagram(fakeDash.buttonEvent(code: 0x06))

        XCTAssertEqual(events, [.button(code: 0x06)])
        XCTAssertEqual(peer.sent.count, 1)
        XCTAssertEqual(K1GPacket.parseOutgoingControl(peer.sent[0].bytes), [
            Tlv(type: 0x06, sub: 0x80, value: [0x06]),
        ])
    }

    func testAuthKeyReplyIsSentThroughTransport() throws {
        let peer = RecordingDatagramPeer()
        let transport = DashTransport(config: .loopbackFakeDash, peer: peer)
        var loop = DashReceiveLoop(
            dispatcher: DashIncomingDispatcher(
                auth: DashAuth(
                    ssid: "RE_TEST",
                    keyGenerator: { [UInt8](repeating: 0x11, count: 32) },
                    encryptor: { _, _, _ in [UInt8](repeating: 0x42, count: 128) }
                )
            ),
            transport: transport
        )
        let fakeDash = FakeDashSession()

        let offered = fakeDash.receiveControl(DashCommands.authRequest())
        XCTAssertEqual(try loop.handleIncomingDatagram(offered.packets[0]), [])
        XCTAssertEqual(try loop.handleIncomingDatagram(offered.packets[1]), [.authKeyRequested])

        XCTAssertEqual(peer.sent.count, 1)
        XCTAssertEqual(peer.sent[0].bytes.count, 149)
        XCTAssertEqual(K1GPacket.parseOutgoingControl(peer.sent[0].bytes).first?.type, 0x08)
        XCTAssertEqual(K1GPacket.parseOutgoingControl(peer.sent[0].bytes).first?.sub, 0x00)
    }
}
