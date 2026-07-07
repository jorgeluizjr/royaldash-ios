import Foundation

public enum DashCommandError: Error, Equatable {
    case invalidCiphertextLength(Int)
}

public enum DashCommands {
    public static func authRequest() -> [UInt8] {
        try! "0016000200000000020100054b314720000804000101".hexBytes()
    }

    public static func authSendKey(ciphertext: [UInt8]) throws -> [UInt8] {
        guard ciphertext.count == 128 else {
            throw DashCommandError.invalidCiphertextLength(ciphertext.count)
        }
        return try "0095000200000000020100054B3147200008000080".hexBytes() + ciphertext
    }

    public static func projectionFrame() -> [UInt8] {
        try! "0016000200000000020100054B314720000556000155".hexBytes()
    }

    public static func frameDecodedIdr() -> [UInt8] {
        try! "0016000200000000020100054B314720000611000155".hexBytes()
    }

    public static func frameDecodedP() -> [UInt8] {
        try! "0016000200000000020100054B314720000612000155".hexBytes()
    }

    public static func buttonAck(_ code: UInt8) -> [UInt8] {
        K1GPacket.build([Tlv(type: 0x06, sub: 0x80, value: [code])])
    }

    public static func hostnameAnnounce(_ hostname: String) -> [UInt8] {
        let raw = Array(hostname.utf8.prefix(200))
        var out = try! "0021000200000000020100054b314720".hexBytes()
        out.append(contentsOf: [0x01, 0x06, 0x0B, 0x00, UInt8(raw.count + 1)])
        out.append(contentsOf: raw)
        out.append(0x00)
        out[0] = UInt8((out.count >> 8) & 0xFF)
        out[1] = UInt8(out.count & 0xFF)
        return out
    }
}
