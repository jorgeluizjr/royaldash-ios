import Foundation

public struct Tlv: Equatable {
    public let type: UInt8
    public let sub: UInt8
    public let value: [UInt8]

    public init(type: UInt8, sub: UInt8, value: [UInt8] = []) {
        self.type = type
        self.sub = sub
        self.value = value
    }
}

public enum K1GPacket {
    private static let magic: [UInt8] = [0x4B, 0x31, 0x47, 0x20]
    private static let fixed: [UInt8] = [
        0x00, 0x00, 0x00, 0x00,
        0x02, 0x01, 0x00, 0x05,
        0x4B, 0x31, 0x47, 0x20,
    ]

    public static func build(_ tlvs: [Tlv]) -> [UInt8] {
        let segmentCount = 1 + tlvs.count
        var out: [UInt8] = [0x00, 0x00]
        out.append(UInt8((segmentCount >> 8) & 0xFF))
        out.append(UInt8(segmentCount & 0xFF))
        out.append(contentsOf: fixed)
        out.append(0x00)

        for tlv in tlvs {
            out.append(tlv.type)
            out.append(tlv.sub)
            out.append(UInt8((tlv.value.count >> 8) & 0xFF))
            out.append(UInt8(tlv.value.count & 0xFF))
            out.append(contentsOf: tlv.value)
        }

        out[0] = UInt8((out.count >> 8) & 0xFF)
        out[1] = UInt8(out.count & 0xFF)
        return out
    }

    public static func patchSequence(_ packet: [UInt8], sequence: Int) -> [UInt8] {
        var out = packet
        if let magicIndex = out.firstIndex(ofSubsequence: magic), magicIndex + 4 < out.count {
            out[magicIndex + 4] = UInt8(sequence & 0xFF)
        }
        out[0] = UInt8((out.count >> 8) & 0xFF)
        out[1] = UInt8(out.count & 0xFF)
        return out
    }

    public static func parseIncoming(_ data: [UInt8]) -> [Tlv] {
        guard data.count >= 8 else { return [] }
        let segmentCount = (Int(data[2]) << 8) | Int(data[3])
        return parseTlvs(data, offset: 8, count: segmentCount)
    }

    public static func buildIncoming(_ tlvs: [Tlv]) -> [UInt8] {
        var out: [UInt8] = [0x00, 0x00]
        out.append(UInt8((tlvs.count >> 8) & 0xFF))
        out.append(UInt8(tlvs.count & 0xFF))
        out.append(contentsOf: [0x00, 0x00, 0x00, 0x00])

        for tlv in tlvs {
            out.append(tlv.type)
            out.append(tlv.sub)
            out.append(UInt8((tlv.value.count >> 8) & 0xFF))
            out.append(UInt8(tlv.value.count & 0xFF))
            out.append(contentsOf: tlv.value)
        }

        out[0] = UInt8((out.count >> 8) & 0xFF)
        out[1] = UInt8(out.count & 0xFF)
        return out
    }

    public static func parseOutgoingControl(_ data: [UInt8]) -> [Tlv] {
        guard data.count >= 17 else { return [] }
        let segmentCount = (Int(data[2]) << 8) | Int(data[3])
        let tlvCount = max(0, segmentCount - 1)
        guard let magicIndex = data.firstIndex(ofSubsequence: magic) else { return [] }
        return parseTlvs(data, offset: magicIndex + 5, count: tlvCount)
    }

    private static func parseTlvs(_ data: [UInt8], offset start: Int, count segmentCount: Int) -> [Tlv] {
        var tlvs: [Tlv] = []
        var offset = start
        var segment = 0

        while segment < segmentCount, offset + 4 <= data.count {
            let type = data[offset]
            let sub = data[offset + 1]
            let length = (Int(data[offset + 2]) << 8) | Int(data[offset + 3])
            offset += 4
            let end = min(offset + length, data.count)
            tlvs.append(Tlv(type: type, sub: sub, value: Array(data[offset..<end])))
            offset = end
            segment += 1
        }

        return tlvs
    }
}

private extension Array where Element == UInt8 {
    func firstIndex(ofSubsequence needle: [UInt8]) -> Int? {
        guard !needle.isEmpty, needle.count <= count else { return nil }

        for start in 0...(count - needle.count) {
            var matched = true
            for index in needle.indices where self[start + index] != needle[index] {
                matched = false
                break
            }
            if matched { return start }
        }

        return nil
    }
}
