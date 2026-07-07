import XCTest
@testable import RoyalDashCore

final class DashIncomingDispatcherTests: XCTestCase {
    func testAuthPublicKeyPacketsProduceEncryptedKeyReply() throws {
        let aes = [UInt8](repeating: 0x11, count: 32)
        let modulus = [UInt8](repeating: 0xA5, count: 128)
        let exponent: [UInt8] = [0x01, 0x00, 0x01]
        var dispatcher = DashIncomingDispatcher(
            auth: DashAuth(
                ssid: "RE_TEST",
                keyGenerator: { aes },
                encryptor: { receivedModulus, receivedExponent, payload in
                    XCTAssertEqual(receivedModulus, modulus)
                    XCTAssertEqual(receivedExponent, exponent)
                    XCTAssertEqual(payload, Array("RE_TEST".utf8) + aes)
                    return [UInt8](repeating: 0x42, count: 128)
                }
            )
        )

        let first = try dispatcher.receive(K1GPacket.buildIncoming([
            Tlv(type: 0x07, sub: 0x00, value: modulus),
        ]))
        XCTAssertEqual(first, DashIncomingResult())

        let second = try dispatcher.receive(K1GPacket.buildIncoming([
            Tlv(type: 0x07, sub: 0x03, value: exponent),
        ]))

        XCTAssertEqual(second.events, [.authKeyRequested])
        XCTAssertEqual(second.replies.count, 1)
        XCTAssertEqual(second.replies[0].count, 149)
        XCTAssertEqual(second.replies[0].suffix(128).map { $0 }, [UInt8](repeating: 0x42, count: 128))
    }

    func testAuthConfirmationAndRejectionRetryFlow() throws {
        var dispatcher = DashIncomingDispatcher(auth: DashAuth(ssid: "RE_TEST"), maxAuthRetries: 1)

        let confirmed = try dispatcher.receive(K1GPacket.buildIncoming([
            Tlv(type: 0x07, sub: 0x01, value: [0x01]),
        ]))
        XCTAssertEqual(confirmed, DashIncomingResult(events: [.authConfirmed]))
        XCTAssertEqual(dispatcher.authRetries, 0)

        let firstReject = try dispatcher.receive(K1GPacket.buildIncoming([
            Tlv(type: 0x07, sub: 0x01, value: [0x00]),
        ]))
        XCTAssertEqual(firstReject.events, [.authRejected(retry: 1, willRetry: true)])
        XCTAssertEqual(firstReject.replies, [DashCommands.authRequest()])

        let secondReject = try dispatcher.receive(K1GPacket.buildIncoming([
            Tlv(type: 0x07, sub: 0x01, value: [0x00]),
        ]))
        XCTAssertEqual(secondReject.events, [.authRejected(retry: 2, willRetry: false)])
        XCTAssertEqual(secondReject.replies, [])
    }

    func testFrameDecodedNotificationsReturnMandatoryAcks() throws {
        var dispatcher = DashIncomingDispatcher(auth: DashAuth(ssid: "RE_TEST"))

        let idr = try dispatcher.receive(K1GPacket.buildIncoming([
            Tlv(type: 0x09, sub: 0x06, value: [0x55]),
        ]))
        XCTAssertEqual(idr.events, [.frameDecoded(kind: .idr)])
        XCTAssertEqual(idr.replies, [DashCommands.frameDecodedIdr()])

        let predicted = try dispatcher.receive(K1GPacket.buildIncoming([
            Tlv(type: 0x09, sub: 0x04, value: [0x55]),
        ]))
        XCTAssertEqual(predicted.events, [.frameDecoded(kind: .predicted)])
        XCTAssertEqual(predicted.replies, [DashCommands.frameDecodedP()])
    }

    func testButtonEventEchoesAckAndUsesLastValueByteAsCode() throws {
        var dispatcher = DashIncomingDispatcher(auth: DashAuth(ssid: "RE_TEST"))

        let result = try dispatcher.receive(K1GPacket.buildIncoming([
            Tlv(type: 0x09, sub: 0x00, value: [0x00, 0x01, 0x06]),
        ]))

        XCTAssertEqual(result.events, [.button(code: 0x06)])
        XCTAssertEqual(result.replies, [DashCommands.buttonAck(0x06)])
    }

    func testUnknownTlvIsReportedWithoutReply() throws {
        var dispatcher = DashIncomingDispatcher(auth: DashAuth(ssid: "RE_TEST"))
        let tlv = Tlv(type: 0x0C, sub: 0x01, value: [0xAA])

        let result = try dispatcher.receive(K1GPacket.buildIncoming([tlv]))

        XCTAssertEqual(result, DashIncomingResult(events: [.unknown(tlv: tlv)]))
    }
}
