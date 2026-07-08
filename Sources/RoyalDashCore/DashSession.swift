import Foundation

public enum DashSessionState: Equatable {
    case idle
    case authenticating
    case authenticated
    case failed(reason: String)
}

public struct DashSession<Peer: DatagramPeer> {
    public private(set) var state: DashSessionState
    public private(set) var receiveLoop: DashReceiveLoop<Peer>

    public init(
        ssid: String,
        config: DashTransportConfig = .tripperDash,
        peer: Peer,
        initialControlSequence: Int = 0,
        maxAuthRetries: Int = 5,
        keyGenerator: @escaping DashAuth.KeyGenerator = DashAuth.secureAes256Key,
        encryptor: @escaping DashAuth.Encryptor = SecurityRsaEncryptor.encrypt
    ) {
        let auth = DashAuth(
            ssid: ssid,
            keyGenerator: keyGenerator,
            encryptor: encryptor
        )
        let dispatcher = DashIncomingDispatcher(
            auth: auth,
            maxAuthRetries: maxAuthRetries
        )
        let transport = DashTransport(
            config: config,
            peer: peer,
            initialControlSequence: initialControlSequence
        )

        self.state = .idle
        self.receiveLoop = DashReceiveLoop(
            dispatcher: dispatcher,
            transport: transport
        )
    }

    public var nextControlSequence: Int {
        receiveLoop.transport.nextControlSequence
    }

    public mutating func startAuthentication() throws {
        try receiveLoop.sendControl(DashCommands.authRequest())
        state = .authenticating
    }

    @discardableResult
    public mutating func handleIncomingDatagram(_ packet: [UInt8]) throws -> [DashIncomingEvent] {
        let events = try receiveLoop.handleIncomingDatagram(packet)
        apply(events)
        return events
    }

    public mutating func sendProjectionFrame() throws {
        try receiveLoop.sendControl(DashCommands.projectionFrame())
    }

    public func sendRtp(_ packet: [UInt8]) throws {
        try receiveLoop.sendRtp(packet)
    }

    private mutating func apply(_ events: [DashIncomingEvent]) {
        for event in events {
            switch event {
            case .authKeyRequested:
                state = .authenticating
            case .authConfirmed:
                state = .authenticated
            case .authRejected(let retry, let willRetry):
                if willRetry {
                    state = .authenticating
                } else {
                    state = .failed(reason: "Authentication rejected after \(retry) attempts.")
                }
            case .frameDecoded, .button, .unknown:
                continue
            }
        }
    }
}
