import Foundation

public enum FakeDashState: String, Equatable {
    case idle
    case publicKeyOffered
    case authenticated
    case projectionActive
}

public enum FakeDashEvent: Equatable {
    case controlPacket(tlvs: [Tlv])
    case authRequestReceived
    case authKeyReceived(ciphertextLength: Int)
    case authRejected(reason: String)
    case projectionFrameReceived
    case projectionOnReceived
    case frameDecodedAckReceived(kind: FrameKind)
    case buttonAckReceived(code: UInt8)
    case rtpPacketReceived(sequence: UInt16, timestamp: UInt32, marker: Bool, payloadBytes: Int)
}

public enum FrameKind: String, Equatable {
    case idr
    case predicted
}

public struct FakeDashResult: Equatable {
    public let packets: [[UInt8]]
    public let events: [FakeDashEvent]

    public init(packets: [[UInt8]] = [], events: [FakeDashEvent] = []) {
        self.packets = packets
        self.events = events
    }
}

public struct FakeDashSession {
    public private(set) var state: FakeDashState = .idle

    public let modulus: [UInt8]
    public let exponent: [UInt8]

    public init(
        modulus: [UInt8] = FakeDashSession.defaultModulus,
        exponent: [UInt8] = [0x01, 0x00, 0x01]
    ) {
        self.modulus = modulus
        self.exponent = exponent
    }

    public mutating func receiveControl(_ packet: [UInt8]) -> FakeDashResult {
        let tlvs = K1GPacket.parseOutgoingControl(packet)
        var packets: [[UInt8]] = []
        var events: [FakeDashEvent] = [.controlPacket(tlvs: tlvs)]

        for tlv in tlvs {
            switch (tlv.type, tlv.sub) {
            case (0x08, 0x04) where tlv.value == [0x01]:
                state = .publicKeyOffered
                events.append(.authRequestReceived)
                packets.append(publicKeyModulusPacket())
                packets.append(publicKeyExponentPacket())
            case (0x08, 0x00) where tlv.value.count == 128:
                state = .authenticated
                events.append(.authKeyReceived(ciphertextLength: tlv.value.count))
                packets.append(authConfirmedPacket())
            case (0x08, 0x00):
                events.append(.authRejected(reason: "Expected 128-byte q3c.d ciphertext, got \(tlv.value.count)."))
                packets.append(authRejectedPacket())
            case (0x05, 0x56) where tlv.value == [0x55]:
                events.append(.projectionFrameReceived)
            case (0x06, 0x05) where tlv.value == [0x55]:
                state = .projectionActive
                events.append(.projectionOnReceived)
            case (0x06, 0x11) where tlv.value == [0x55]:
                events.append(.frameDecodedAckReceived(kind: .idr))
            case (0x06, 0x12) where tlv.value == [0x55]:
                events.append(.frameDecodedAckReceived(kind: .predicted))
            case (0x06, 0x80) where tlv.value.count == 1:
                events.append(.buttonAckReceived(code: tlv.value[0]))
            default:
                continue
            }
        }

        return FakeDashResult(packets: packets, events: events)
    }

    public func receiveRtp(_ packet: [UInt8]) -> FakeDashResult {
        guard packet.count >= 12 else {
            return FakeDashResult(events: [.authRejected(reason: "RTP packet shorter than 12-byte header.")])
        }

        let sequence = (UInt16(packet[2]) << 8) | UInt16(packet[3])
        let timestamp = (UInt32(packet[4]) << 24) |
            (UInt32(packet[5]) << 16) |
            (UInt32(packet[6]) << 8) |
            UInt32(packet[7])
        let marker = (packet[1] & 0x80) != 0

        return FakeDashResult(events: [
            .rtpPacketReceived(
                sequence: sequence,
                timestamp: timestamp,
                marker: marker,
                payloadBytes: packet.count - 12
            ),
        ])
    }

    public func frameDecodedNotify(kind: FrameKind) -> [UInt8] {
        switch kind {
        case .idr:
            return K1GPacket.buildIncoming([Tlv(type: 0x09, sub: 0x06, value: [0x55])])
        case .predicted:
            return K1GPacket.buildIncoming([Tlv(type: 0x09, sub: 0x04, value: [0x55])])
        }
    }

    public func buttonEvent(code: UInt8) -> [UInt8] {
        K1GPacket.buildIncoming([Tlv(type: 0x09, sub: 0x00, value: [0x00, 0x01, code])])
    }

    private func publicKeyModulusPacket() -> [UInt8] {
        K1GPacket.buildIncoming([Tlv(type: 0x07, sub: 0x00, value: modulus)])
    }

    private func publicKeyExponentPacket() -> [UInt8] {
        K1GPacket.buildIncoming([Tlv(type: 0x07, sub: 0x03, value: exponent)])
    }

    private func authConfirmedPacket() -> [UInt8] {
        K1GPacket.buildIncoming([Tlv(type: 0x07, sub: 0x01, value: [0x01])])
    }

    private func authRejectedPacket() -> [UInt8] {
        K1GPacket.buildIncoming([Tlv(type: 0x07, sub: 0x01, value: [0x00])])
    }

    public static let defaultModulus: [UInt8] = Array(repeating: 0xA5, count: 128)
}
