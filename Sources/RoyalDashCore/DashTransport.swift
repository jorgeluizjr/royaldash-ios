import Foundation
import Network

public struct UdpEndpoint: Equatable, CustomStringConvertible {
    public let host: String
    public let port: UInt16

    public init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }

    public var description: String {
        "\(host):\(port)"
    }
}

public struct SentDatagram: Equatable {
    public let bytes: [UInt8]
    public let endpoint: UdpEndpoint

    public init(bytes: [UInt8], endpoint: UdpEndpoint) {
        self.bytes = bytes
        self.endpoint = endpoint
    }
}

public protocol DatagramPeer {
    func send(_ bytes: [UInt8], to endpoint: UdpEndpoint) throws
}

public struct DashTransportConfig: Equatable {
    public let controlBroadcast: UdpEndpoint
    public let dashRtp: UdpEndpoint
    public let controlLocalPort: UInt16
    public let receiveLocalPort: UInt16

    public init(
        controlBroadcast: UdpEndpoint,
        dashRtp: UdpEndpoint,
        controlLocalPort: UInt16,
        receiveLocalPort: UInt16
    ) {
        self.controlBroadcast = controlBroadcast
        self.dashRtp = dashRtp
        self.controlLocalPort = controlLocalPort
        self.receiveLocalPort = receiveLocalPort
    }

    public static let tripperDash = DashTransportConfig(
        controlBroadcast: UdpEndpoint(host: "192.168.1.255", port: 2000),
        dashRtp: UdpEndpoint(host: "192.168.1.1", port: 5000),
        controlLocalPort: 2000,
        receiveLocalPort: 2002
    )

    public static let tripperDashUnicastControl = DashTransportConfig(
        controlBroadcast: UdpEndpoint(host: "192.168.1.1", port: 2000),
        dashRtp: UdpEndpoint(host: "192.168.1.1", port: 5000),
        controlLocalPort: 2000,
        receiveLocalPort: 2002
    )

    public static let loopbackFakeDash = DashTransportConfig(
        controlBroadcast: UdpEndpoint(host: "127.0.0.1", port: 2000),
        dashRtp: UdpEndpoint(host: "127.0.0.1", port: 5000),
        controlLocalPort: 2000,
        receiveLocalPort: 2002
    )
}

public struct DashTransport<Peer: DatagramPeer> {
    public private(set) var nextControlSequence: Int

    private let config: DashTransportConfig
    private let peer: Peer

    public init(
        config: DashTransportConfig = .tripperDash,
        peer: Peer,
        initialControlSequence: Int = 0
    ) {
        self.config = config
        self.peer = peer
        self.nextControlSequence = initialControlSequence
    }

    public mutating func sendControl(_ packet: [UInt8]) throws {
        let sequenced = K1GPacket.patchSequence(packet, sequence: nextControlSequence)
        nextControlSequence = (nextControlSequence + 1) & 0xFF
        try peer.send(sequenced, to: config.controlBroadcast)
    }

    public func sendRtp(_ packet: [UInt8]) throws {
        try peer.send(packet, to: config.dashRtp)
    }
}

public final class RecordingDatagramPeer: DatagramPeer {
    public private(set) var sent: [SentDatagram] = []

    public init() {}

    public func send(_ bytes: [UInt8], to endpoint: UdpEndpoint) {
        sent.append(SentDatagram(bytes: bytes, endpoint: endpoint))
    }
}

public enum NetworkUdpPeerError: Error, Equatable {
    case invalidPort(UInt16)
    case sendFailed(String)
}

extension NetworkUdpPeerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidPort(let port):
            return "Porta UDP invalida: \(port)."
        case .sendFailed(let reason):
            return "Falha ao enviar UDP: \(reason)."
        }
    }
}

public final class NetworkUdpPeer: DatagramPeer {
    private let queue: DispatchQueue
    private let localPort: UInt16?

    public init(
        localPort: UInt16? = nil,
        queue: DispatchQueue = DispatchQueue(label: "RoyalDash.NetworkUdpPeer")
    ) {
        self.localPort = localPort
        self.queue = queue
    }

    public func send(_ bytes: [UInt8], to endpoint: UdpEndpoint) throws {
        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
            throw NetworkUdpPeerError.invalidPort(endpoint.port)
        }

        let parameters = NWParameters.udp
        if let localPort {
            guard let nwLocalPort = NWEndpoint.Port(rawValue: localPort) else {
                throw NetworkUdpPeerError.invalidPort(localPort)
            }
            parameters.requiredLocalEndpoint = .hostPort(
                host: .ipv4(IPv4Address("0.0.0.0")!),
                port: nwLocalPort
            )
        }

        let connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: port,
            using: parameters
        )

        let group = DispatchGroup()
        group.enter()
        var sendError: Error?

        connection.start(queue: queue)
        connection.send(content: Data(bytes), completion: .contentProcessed { error in
            sendError = error
            connection.cancel()
            group.leave()
        })
        group.wait()

        if let sendError {
            throw NetworkUdpPeerError.sendFailed(sendError.localizedDescription)
        }
    }
}
