import Foundation

public enum H264NalFormat: Equatable {
    case annexB
    case avcc(lengthSize: Int)
}

public enum H264NalProcessorError: Error, Equatable {
    case invalidAvccLengthSize(Int)
    case truncatedAvccLength
    case truncatedNal(expected: Int, remaining: Int)
}

public struct H264NalUnit: Equatable {
    public let bytes: [UInt8]

    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }

    public var type: UInt8 {
        bytes.first.map { $0 & 0x1F } ?? 0
    }

    public var isIdr: Bool {
        type == 5
    }

    public var isParameterSet: Bool {
        type == 7 || type == 8
    }
}

public struct H264NalProcessor {
    public private(set) var cachedSps: [UInt8]?
    public private(set) var cachedPps: [UInt8]?

    public init(cachedSps: [UInt8]? = nil, cachedPps: [UInt8]? = nil) {
        self.cachedSps = cachedSps
        self.cachedPps = cachedPps
    }

    public mutating func process(accessUnit bytes: [UInt8], format: H264NalFormat) throws -> [H264NalUnit] {
        switch format {
        case .annexB:
            return process(nalUnits: Self.parseAnnexB(bytes))
        case .avcc(let lengthSize):
            return try process(nalUnits: Self.parseAvcc(bytes, lengthSize: lengthSize))
        }
    }

    public mutating func process(nalUnits rawUnits: [[UInt8]]) -> [H264NalUnit] {
        var output: [H264NalUnit] = []
        var hasIdr = false
        var hasSps = false
        var hasPps = false

        for raw in rawUnits where !raw.isEmpty {
            let unit = H264NalUnit(bytes: raw)

            switch unit.type {
            case 6, 9:
                continue
            case 7:
                cachedSps = raw
                hasSps = true
                output.append(unit)
            case 8:
                cachedPps = raw
                hasPps = true
                output.append(unit)
            case 5:
                hasIdr = true
                output.append(unit)
            default:
                output.append(unit)
            }
        }

        guard hasIdr else {
            return output
        }

        var prefix: [H264NalUnit] = []
        if !hasSps, let cachedSps {
            prefix.append(H264NalUnit(bytes: cachedSps))
        }
        if !hasPps, let cachedPps {
            prefix.append(H264NalUnit(bytes: cachedPps))
        }
        return prefix + output
    }

    private static func parseAnnexB(_ bytes: [UInt8]) -> [[UInt8]] {
        let starts = annexBStarts(in: bytes)
        guard !starts.isEmpty else {
            return bytes.isEmpty ? [] : [bytes]
        }

        return starts.enumerated().compactMap { index, start in
            let end = index + 1 < starts.count ? starts[index + 1].codeStart : bytes.count
            guard start.nalStart < end else { return nil }
            return Array(bytes[start.nalStart..<end])
        }
    }

    private static func annexBStarts(in bytes: [UInt8]) -> [(codeStart: Int, nalStart: Int)] {
        var starts: [(codeStart: Int, nalStart: Int)] = []
        var index = 0

        while index + 3 <= bytes.count {
            if index + 4 <= bytes.count,
               bytes[index] == 0,
               bytes[index + 1] == 0,
               bytes[index + 2] == 0,
               bytes[index + 3] == 1 {
                starts.append((codeStart: index, nalStart: index + 4))
                index += 4
            } else if bytes[index] == 0,
                      bytes[index + 1] == 0,
                      bytes[index + 2] == 1 {
                starts.append((codeStart: index, nalStart: index + 3))
                index += 3
            } else {
                index += 1
            }
        }

        return starts
    }

    private static func parseAvcc(_ bytes: [UInt8], lengthSize: Int) throws -> [[UInt8]] {
        guard (1...4).contains(lengthSize) else {
            throw H264NalProcessorError.invalidAvccLengthSize(lengthSize)
        }

        var offset = 0
        var units: [[UInt8]] = []

        while offset < bytes.count {
            guard offset + lengthSize <= bytes.count else {
                throw H264NalProcessorError.truncatedAvccLength
            }

            var length = 0
            for byte in bytes[offset..<(offset + lengthSize)] {
                length = (length << 8) | Int(byte)
            }
            offset += lengthSize

            guard offset + length <= bytes.count else {
                throw H264NalProcessorError.truncatedNal(
                    expected: length,
                    remaining: bytes.count - offset
                )
            }

            if length > 0 {
                units.append(Array(bytes[offset..<(offset + length)]))
            }
            offset += length
        }

        return units
    }
}
