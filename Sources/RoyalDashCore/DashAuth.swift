import Foundation
import Security

public enum DashAuthEvent: Equatable {
    case sendKey(packet: [UInt8])
    case confirmed
    case rejected
    case none
}

public enum DashAuthError: Error, Equatable {
    case randomGenerationFailed(OSStatus)
    case publicKeyBuildFailed
    case encryptionFailed(String)
}

public struct DashAuth {
    public typealias KeyGenerator = () throws -> [UInt8]
    public typealias Encryptor = (_ modulus: [UInt8], _ exponent: [UInt8], _ payload: [UInt8]) throws -> [UInt8]

    public private(set) var sessionKey: [UInt8]?

    private let ssid: String
    private let keyGenerator: KeyGenerator
    private let encryptor: Encryptor

    private var modulus: [UInt8]?
    private var exponent: [UInt8]?
    private var keySent = false

    public init(
        ssid: String,
        keyGenerator: @escaping KeyGenerator = DashAuth.secureAes256Key,
        encryptor: @escaping Encryptor = SecurityRsaEncryptor.encrypt
    ) {
        self.ssid = ssid
        self.keyGenerator = keyGenerator
        self.encryptor = encryptor
    }

    public mutating func ingest(_ tlv: Tlv) throws -> DashAuthEvent {
        guard tlv.type == 0x07 else { return .none }

        switch tlv.sub {
        case 0x00:
            modulus = tlv.value
        case 0x03:
            exponent = tlv.value
        case 0x01:
            return tlv.value.first == 0x01 ? .confirmed : .rejected
        default:
            return .none
        }

        guard !keySent, let modulus, let exponent else { return .none }
        keySent = true
        return .sendKey(packet: try buildKeyPacket(modulus: modulus, exponent: exponent))
    }

    public mutating func reset() {
        modulus = nil
        exponent = nil
        keySent = false
    }

    private mutating func buildKeyPacket(modulus: [UInt8], exponent: [UInt8]) throws -> [UInt8] {
        let aes = try keyGenerator()
        sessionKey = aes

        let payload = Array(ssid.utf8) + aes
        let ciphertext = try encryptor(modulus, exponent, payload)
        return try DashCommands.authSendKey(ciphertext: ciphertext)
    }

    public static func secureAes256Key() throws -> [UInt8] {
        var key = [UInt8](repeating: 0, count: 32)
        let byteCount = key.count
        let status = key.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, byteCount, buffer.baseAddress!)
        }
        guard status == errSecSuccess else {
            throw DashAuthError.randomGenerationFailed(status)
        }
        return key
    }
}

public enum SecurityRsaEncryptor {
    public static func encrypt(modulus: [UInt8], exponent: [UInt8], payload: [UInt8]) throws -> [UInt8] {
        let der = Der.rsaPublicKey(modulus: modulus, exponent: exponent)
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits: modulus.count * 8,
        ]

        var keyError: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(Data(der) as CFData, attributes as CFDictionary, &keyError) else {
            throw DashAuthError.publicKeyBuildFailed
        }

        var encryptError: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(
            key,
            .rsaEncryptionPKCS1,
            Data(payload) as CFData,
            &encryptError
        ) else {
            let message = encryptError?.takeRetainedValue().localizedDescription ?? "unknown Security.framework error"
            throw DashAuthError.encryptionFailed(message)
        }

        return Array(encrypted as Data)
    }
}

private enum Der {
    static func rsaPublicKey(modulus: [UInt8], exponent: [UInt8]) -> [UInt8] {
        sequence(integer(modulus) + integer(exponent))
    }

    private static func sequence(_ value: [UInt8]) -> [UInt8] {
        [0x30] + length(value.count) + value
    }

    private static func integer(_ value: [UInt8]) -> [UInt8] {
        var normalized = Array(value.drop { $0 == 0x00 })
        if normalized.isEmpty {
            normalized = [0x00]
        }
        if let first = normalized.first, (first & 0x80) != 0 {
            normalized.insert(0x00, at: 0)
        }
        return [0x02] + length(normalized.count) + normalized
    }

    private static func length(_ count: Int) -> [UInt8] {
        if count < 0x80 {
            return [UInt8(count)]
        }

        var bytes: [UInt8] = []
        var value = count
        while value > 0 {
            bytes.insert(UInt8(value & 0xFF), at: 0)
            value >>= 8
        }
        return [0x80 | UInt8(bytes.count)] + bytes
    }
}
