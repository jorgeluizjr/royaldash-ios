import XCTest
@testable import RoyalDashCore

final class DashAuthTests: XCTestCase {
    func testEmitsKeyPacketOnlyAfterBothPublicKeyPartsArrive() throws {
        let aes = [UInt8](repeating: 0x11, count: 32)
        let modulus = [UInt8](repeating: 0xA5, count: 128)
        let exponent: [UInt8] = [0x01, 0x00, 0x01]
        var capturedPayload: [UInt8] = []
        var auth = DashAuth(
            ssid: "RE_TEST",
            keyGenerator: { aes },
            encryptor: { receivedModulus, receivedExponent, payload in
                XCTAssertEqual(receivedModulus, modulus)
                XCTAssertEqual(receivedExponent, exponent)
                capturedPayload = payload
                return [UInt8](repeating: 0x42, count: 128)
            }
        )

        let first = try auth.ingest(Tlv(type: 0x07, sub: 0x00, value: modulus))
        XCTAssertEqual(first, .none)

        let second = try auth.ingest(Tlv(type: 0x07, sub: 0x03, value: exponent))

        XCTAssertEqual(auth.sessionKey, aes)
        XCTAssertEqual(capturedPayload, Array("RE_TEST".utf8) + aes)
        if case .sendKey(let packet) = second {
            XCTAssertEqual(packet.count, 149)
            XCTAssertEqual(packet.prefix(21).map { $0 }.hexString(separator: ""), "0095000200000000020100054B3147200008000080")
            XCTAssertEqual(packet.suffix(128).map { $0 }, [UInt8](repeating: 0x42, count: 128))
        } else {
            XCTFail("Expected sendKey event, got \(second)")
        }
    }

    func testAcceptsPublicKeyPartsInEitherOrder() throws {
        var auth = DashAuth(
            ssid: "RE_TEST",
            keyGenerator: { [UInt8](repeating: 0x11, count: 32) },
            encryptor: { _, _, _ in [UInt8](repeating: 0x42, count: 128) }
        )

        XCTAssertEqual(try auth.ingest(Tlv(type: 0x07, sub: 0x03, value: [0x01, 0x00, 0x01])), .none)
        let event = try auth.ingest(Tlv(type: 0x07, sub: 0x00, value: [UInt8](repeating: 0xA5, count: 128)))

        if case .sendKey = event {} else {
            XCTFail("Expected sendKey event, got \(event)")
        }
    }

    func testDoesNotEmitDuplicateKeyUntilReset() throws {
        var encryptCount = 0
        let modulus = [UInt8](repeating: 0xA5, count: 128)
        let exponent: [UInt8] = [0x01, 0x00, 0x01]
        var auth = DashAuth(
            ssid: "RE_TEST",
            keyGenerator: { [UInt8](repeating: 0x11, count: 32) },
            encryptor: { _, _, _ in
                encryptCount += 1
                return [UInt8](repeating: 0x42, count: 128)
            }
        )

        _ = try auth.ingest(Tlv(type: 0x07, sub: 0x00, value: modulus))
        _ = try auth.ingest(Tlv(type: 0x07, sub: 0x03, value: exponent))
        let duplicate = try auth.ingest(Tlv(type: 0x07, sub: 0x03, value: exponent))

        XCTAssertEqual(duplicate, .none)
        XCTAssertEqual(encryptCount, 1)

        auth.reset()
        _ = try auth.ingest(Tlv(type: 0x07, sub: 0x00, value: modulus))
        let afterReset = try auth.ingest(Tlv(type: 0x07, sub: 0x03, value: exponent))

        if case .sendKey = afterReset {} else {
            XCTFail("Expected sendKey after reset, got \(afterReset)")
        }
        XCTAssertEqual(encryptCount, 2)
    }

    func testConfirmationAndRejectionEvents() throws {
        var auth = DashAuth(ssid: "RE_TEST")

        XCTAssertEqual(try auth.ingest(Tlv(type: 0x07, sub: 0x01, value: [0x01])), .confirmed)
        XCTAssertEqual(try auth.ingest(Tlv(type: 0x07, sub: 0x01, value: [0x00])), .rejected)
        XCTAssertEqual(try auth.ingest(Tlv(type: 0x06, sub: 0x01, value: [0x01])), .none)
    }

    func testRealSecurityEncryptorProducesRsaSizedCiphertext() throws {
        let modulus = try "BCC4CE20B9280F92A80531DACA4EEE3311B8B55FC485223258BDE97D7DD131BE37E3AF9E5758FBA0AE1019A7BDAC061C877CE5F08B81DEC297391B2924DEF326A052C1B03DF7CC76FA98201159D367CD5555E633857299F8334C8EA8299078B04ADE6AAFEE6A180D96226A9497605513C3C252236D9E6E2064C4185D446D8359".hexBytes()
        let exponent = try "010001".hexBytes()

        let encrypted = try SecurityRsaEncryptor.encrypt(
            modulus: modulus,
            exponent: exponent,
            payload: Array("RE_TEST".utf8) + [UInt8](repeating: 0x11, count: 32)
        )

        XCTAssertEqual(encrypted.count, 128)
    }
}
