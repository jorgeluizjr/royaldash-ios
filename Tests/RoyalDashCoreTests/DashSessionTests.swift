import XCTest
@testable import RoyalDashCore

final class DashSessionTests: XCTestCase {
    func testStartAuthenticationSendsFrozenAuthRequest() throws {
        let peer = RecordingDatagramPeer()
        var session = DashSession(
            ssid: "RE_TEST",
            config: .loopbackFakeDash,
            peer: peer,
            initialControlSequence: 0x20
        )

        try session.startAuthentication()

        XCTAssertEqual(session.state, .authenticating)
        XCTAssertEqual(session.nextControlSequence, 0x21)
        XCTAssertEqual(peer.sent.count, 1)
        XCTAssertEqual(peer.sent[0].endpoint, UdpEndpoint(host: "127.0.0.1", port: 2000))
        XCTAssertEqual(peer.sent[0].bytes[16], 0x20)
        XCTAssertEqual(K1GPacket.parseOutgoingControl(peer.sent[0].bytes), [
            Tlv(type: 0x08, sub: 0x04, value: [0x01]),
        ])
    }

    func testFakeDashAuthHandshakeReachesAuthenticatedState() throws {
        let peer = RecordingDatagramPeer()
        var fakeDash = FakeDashSession()
        var session = DashSession(
            ssid: "RE_TEST",
            config: .loopbackFakeDash,
            peer: peer,
            keyGenerator: { [UInt8](repeating: 0x11, count: 32) },
            encryptor: { _, _, _ in [UInt8](repeating: 0x42, count: 128) }
        )

        try session.startAuthentication()
        let offeredKey = fakeDash.receiveControl(peer.sent[0].bytes)

        XCTAssertEqual(try session.handleIncomingDatagram(offeredKey.packets[0]), [])
        XCTAssertEqual(try session.handleIncomingDatagram(offeredKey.packets[1]), [.authKeyRequested])
        XCTAssertEqual(session.state, .authenticating)
        XCTAssertEqual(peer.sent.count, 2)

        let confirmed = fakeDash.receiveControl(peer.sent[1].bytes)
        XCTAssertEqual(try session.handleIncomingDatagram(confirmed.packets[0]), [.authConfirmed])
        XCTAssertEqual(session.state, .authenticated)
    }

    func testAuthRejectionRetriesThenFails() throws {
        let peer = RecordingDatagramPeer()
        var session = DashSession(
            ssid: "RE_TEST",
            config: .loopbackFakeDash,
            peer: peer,
            maxAuthRetries: 1
        )
        let rejected = K1GPacket.buildIncoming([
            Tlv(type: 0x07, sub: 0x01, value: [0x00]),
        ])

        try session.startAuthentication()
        XCTAssertEqual(try session.handleIncomingDatagram(rejected), [
            .authRejected(retry: 1, willRetry: true),
        ])
        XCTAssertEqual(session.state, .authenticating)
        XCTAssertEqual(peer.sent.count, 2)

        XCTAssertEqual(try session.handleIncomingDatagram(rejected), [
            .authRejected(retry: 2, willRetry: false),
        ])
        XCTAssertEqual(session.state, .failed(reason: "Authentication rejected after 2 attempts."))
        XCTAssertEqual(peer.sent.count, 2)
    }

    func testProjectionFrameAndRtpUseConfiguredEndpoints() throws {
        let peer = RecordingDatagramPeer()
        var session = DashSession(
            ssid: "RE_TEST",
            config: .loopbackFakeDash,
            peer: peer
        )
        let rtpPacket: [UInt8] = [0x80, 0xE0, 0x00, 0x01, 0xAA]

        try session.sendProjectionFrame()
        try session.sendRtp(rtpPacket)

        XCTAssertEqual(peer.sent.map(\.endpoint), [
            UdpEndpoint(host: "127.0.0.1", port: 2000),
            UdpEndpoint(host: "127.0.0.1", port: 5000),
        ])
        XCTAssertEqual(K1GPacket.parseOutgoingControl(peer.sent[0].bytes), [
            Tlv(type: 0x05, sub: 0x56, value: [0x55]),
        ])
        XCTAssertEqual(peer.sent[1].bytes, rtpPacket)
    }
}
