import Foundation

public enum DashIncomingEvent: Equatable {
    case authKeyRequested
    case authConfirmed
    case authRejected(retry: Int, willRetry: Bool)
    case frameDecoded(kind: FrameKind)
    case button(code: UInt8)
    case unknown(tlv: Tlv)
}

public struct DashIncomingResult: Equatable {
    public let replies: [[UInt8]]
    public let events: [DashIncomingEvent]

    public init(replies: [[UInt8]] = [], events: [DashIncomingEvent] = []) {
        self.replies = replies
        self.events = events
    }
}

public struct DashIncomingDispatcher {
    public private(set) var auth: DashAuth
    public private(set) var authRetries: Int

    private let maxAuthRetries: Int

    public init(auth: DashAuth, maxAuthRetries: Int = 5) {
        self.auth = auth
        self.authRetries = 0
        self.maxAuthRetries = maxAuthRetries
    }

    public mutating func receive(_ packet: [UInt8]) throws -> DashIncomingResult {
        var replies: [[UInt8]] = []
        var events: [DashIncomingEvent] = []

        for tlv in K1GPacket.parseIncoming(packet) {
            let result = try dispatch(tlv)
            replies.append(contentsOf: result.replies)
            events.append(contentsOf: result.events)
        }

        return DashIncomingResult(replies: replies, events: events)
    }

    private mutating func dispatch(_ tlv: Tlv) throws -> DashIncomingResult {
        if tlv.type == 0x07 {
            return try dispatchAuth(tlv)
        }

        if tlv.type == 0x09, tlv.sub == 0x06, tlv.value.first == 0x55 {
            return DashIncomingResult(
                replies: [DashCommands.frameDecodedIdr()],
                events: [.frameDecoded(kind: .idr)]
            )
        }

        if tlv.type == 0x09, tlv.sub == 0x04, tlv.value.first == 0x55 {
            return DashIncomingResult(
                replies: [DashCommands.frameDecodedP()],
                events: [.frameDecoded(kind: .predicted)]
            )
        }

        if tlv.type == 0x09, tlv.sub == 0x00, let code = tlv.value.last {
            return DashIncomingResult(
                replies: [DashCommands.buttonAck(code)],
                events: [.button(code: code)]
            )
        }

        return DashIncomingResult(events: [.unknown(tlv: tlv)])
    }

    private mutating func dispatchAuth(_ tlv: Tlv) throws -> DashIncomingResult {
        switch try auth.ingest(tlv) {
        case .sendKey(let packet):
            return DashIncomingResult(
                replies: [packet],
                events: [.authKeyRequested]
            )
        case .confirmed:
            authRetries = 0
            return DashIncomingResult(events: [.authConfirmed])
        case .rejected:
            authRetries += 1
            auth.reset()
            let shouldRetry = authRetries <= maxAuthRetries
            let replies = shouldRetry ? [DashCommands.authRequest()] : []
            return DashIncomingResult(
                replies: replies,
                events: [.authRejected(retry: authRetries, willRetry: shouldRetry)]
            )
        case .none:
            return DashIncomingResult()
        }
    }
}
