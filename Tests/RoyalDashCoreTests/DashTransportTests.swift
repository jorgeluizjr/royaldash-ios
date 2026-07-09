import XCTest
@testable import RoyalDashCore

final class DashTransportTests: XCTestCase {
    func testControlPacketsAreSequencedAndSentToBroadcastEndpoint() throws {
        let peer = RecordingDatagramPeer()
        var transport = DashTransport(
            config: .tripperDash,
            peer: peer,
            initialControlSequence: 0x2A
        )

        try transport.sendControl(DashCommands.authRequest())
        try transport.sendControl(DashCommands.projectionFrame())

        XCTAssertEqual(peer.sent.map(\.endpoint), [
            UdpEndpoint(host: "192.168.1.255", port: 2000),
            UdpEndpoint(host: "192.168.1.255", port: 2000),
        ])
        XCTAssertEqual(peer.sent[0].bytes[16], 0x2A)
        XCTAssertEqual(peer.sent[1].bytes[16], 0x2B)
        XCTAssertEqual(transport.nextControlSequence, 0x2C)
    }

    func testControlSequenceRollsOverAtOneByte() throws {
        let peer = RecordingDatagramPeer()
        var transport = DashTransport(
            config: .loopbackFakeDash,
            peer: peer,
            initialControlSequence: 0xFF
        )

        try transport.sendControl(DashCommands.authRequest())
        try transport.sendControl(DashCommands.authRequest())

        XCTAssertEqual(peer.sent[0].bytes[16], 0xFF)
        XCTAssertEqual(peer.sent[1].bytes[16], 0x00)
        XCTAssertEqual(transport.nextControlSequence, 0x01)
    }

    func testRtpPacketsAreSentToDashRtpEndpointWithoutMutation() throws {
        let peer = RecordingDatagramPeer()
        let transport = DashTransport(config: .tripperDash, peer: peer)
        let packet: [UInt8] = [0x80, 0xE0, 0x00, 0x01, 0xAA]

        try transport.sendRtp(packet)

        XCTAssertEqual(peer.sent, [
            SentDatagram(
                bytes: packet,
                endpoint: UdpEndpoint(host: "192.168.1.1", port: 5000)
            ),
        ])
    }

    func testLoopbackFakeDashConfigUsesLocalhostEndpoints() {
        XCTAssertEqual(DashTransportConfig.loopbackFakeDash.controlBroadcast, UdpEndpoint(host: "127.0.0.1", port: 2000))
        XCTAssertEqual(DashTransportConfig.loopbackFakeDash.dashRtp, UdpEndpoint(host: "127.0.0.1", port: 5000))
        XCTAssertEqual(DashTransportConfig.loopbackFakeDash.controlLocalPort, 2000)
        XCTAssertEqual(DashTransportConfig.loopbackFakeDash.receiveLocalPort, 2002)
    }

    func testTripperDashUnicastControlConfigTargetsDashIp() {
        XCTAssertEqual(DashTransportConfig.tripperDashUnicastControl.controlBroadcast, UdpEndpoint(host: "192.168.1.1", port: 2000))
        XCTAssertEqual(DashTransportConfig.tripperDashUnicastControl.dashRtp, UdpEndpoint(host: "192.168.1.1", port: 5000))
        XCTAssertEqual(DashTransportConfig.tripperDashUnicastControl.controlLocalPort, 2000)
        XCTAssertEqual(DashTransportConfig.tripperDashUnicastControl.receiveLocalPort, 2002)
    }
}
