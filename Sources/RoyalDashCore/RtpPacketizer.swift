import Foundation

public struct RtpPacketizer {
    public static let maxPayload = 1380
    public static let payloadType: UInt8 = 96

    private var sequence: UInt16
    private let ssrc: UInt32
    private let timestampBase: UInt32
    private let onPacket: ([UInt8]) -> Void

    public init(
        initialSequence: UInt16 = 0,
        ssrc: UInt32 = 0x1020_3040,
        timestampBase: UInt32 = 0,
        onPacket: @escaping ([UInt8]) -> Void
    ) {
        self.sequence = initialSequence
        self.ssrc = ssrc
        self.timestampBase = timestampBase
        self.onPacket = onPacket
    }

    public mutating func packetize(nal: [UInt8], endOfAccessUnit: Bool, wallClockMs: UInt32) {
        let timestamp = timestampBase &+ wallClockMs &* 90
        if nal.count <= Self.maxPayload {
            emit(payload: nal, marker: endOfAccessUnit, timestamp: timestamp)
        } else {
            fragmentFuA(nal: nal, endOfAccessUnit: endOfAccessUnit, timestamp: timestamp)
        }
    }

    private mutating func fragmentFuA(nal: [UInt8], endOfAccessUnit: Bool, timestamp: UInt32) {
        guard let first = nal.first else { return }
        let nalType = first & 0x1F
        let fuIndicator = (first & 0xE0) | 28
        var offset = 1
        var isFirst = true

        while offset < nal.count {
            let remaining = nal.count - offset
            let chunkLength = min(Self.maxPayload - 2, remaining)
            let isLast = chunkLength >= remaining
            let fuHeader = (isFirst ? 0x80 : 0x00) | (isLast ? 0x40 : 0x00) | nalType
            let payload = [fuIndicator, fuHeader] + Array(nal[offset..<(offset + chunkLength)])
            emit(payload: payload, marker: isLast && endOfAccessUnit, timestamp: timestamp)
            offset += chunkLength
            isFirst = false
        }
    }

    private mutating func emit(payload: [UInt8], marker: Bool, timestamp: UInt32) {
        var packet = [UInt8](repeating: 0, count: 12)
        packet[0] = 0x80
        packet[1] = (marker ? 0x80 : 0x00) | Self.payloadType
        packet[2] = UInt8((sequence >> 8) & 0xFF)
        packet[3] = UInt8(sequence & 0xFF)
        packet[4] = UInt8((timestamp >> 24) & 0xFF)
        packet[5] = UInt8((timestamp >> 16) & 0xFF)
        packet[6] = UInt8((timestamp >> 8) & 0xFF)
        packet[7] = UInt8(timestamp & 0xFF)
        packet[8] = UInt8((ssrc >> 24) & 0xFF)
        packet[9] = UInt8((ssrc >> 16) & 0xFF)
        packet[10] = UInt8((ssrc >> 8) & 0xFF)
        packet[11] = UInt8(ssrc & 0xFF)
        packet.append(contentsOf: payload)
        sequence &+= 1
        onPacket(packet)
    }
}
