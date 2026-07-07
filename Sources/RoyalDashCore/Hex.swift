import Foundation

public enum HexError: Error, Equatable {
    case oddLength
    case invalidByte(String)
}

public extension String {
    func hexBytes() throws -> [UInt8] {
        let clean = filter { !$0.isWhitespace }
        guard clean.count.isMultiple(of: 2) else { throw HexError.oddLength }

        var output: [UInt8] = []
        output.reserveCapacity(clean.count / 2)

        var index = clean.startIndex
        while index < clean.endIndex {
            let next = clean.index(index, offsetBy: 2)
            let token = String(clean[index..<next])
            guard let byte = UInt8(token, radix: 16) else {
                throw HexError.invalidByte(token)
            }
            output.append(byte)
            index = next
        }

        return output
    }
}

public extension Array where Element == UInt8 {
    func hexString(separator: String = " ") -> String {
        map { String(format: "%02X", $0) }.joined(separator: separator)
    }
}
