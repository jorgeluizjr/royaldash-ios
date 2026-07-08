import Foundation
import Network

public struct DashReceiveLoop<Peer: DatagramPeer> {
    public private(set) var dispatcher: DashIncomingDispatcher
    public private(set) var transport: DashTransport<Peer>

    public init(dispatcher: DashIncomingDispatcher, transport: DashTransport<Peer>) {
        self.dispatcher = dispatcher
        self.transport = transport
    }

    public mutating func sendControl(_ packet: [UInt8]) throws {
        try transport.sendControl(packet)
    }

    public func sendRtp(_ packet: [UInt8]) throws {
        try transport.sendRtp(packet)
    }

    @discardableResult
    public mutating func handleIncomingDatagram(_ packet: [UInt8]) throws -> [DashIncomingEvent] {
        let result = try dispatcher.receive(packet)
        for reply in result.replies {
            try transport.sendControl(reply)
        }
        return result.events
    }
}

public enum NetworkUdpReceiverError: Error, Equatable {
    case invalidPort(UInt16)
}

public final class NetworkUdpReceiver {
    private let port: UInt16
    private let queue: DispatchQueue
    private var listener: NWListener?

    public init(
        port: UInt16,
        queue: DispatchQueue = DispatchQueue(label: "RoyalDash.NetworkUdpReceiver")
    ) {
        self.port = port
        self.queue = queue
    }

    public func start(onDatagram: @escaping ([UInt8]) -> Void) throws {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            throw NetworkUdpReceiverError.invalidPort(port)
        }

        let listener = try NWListener(using: .udp, on: nwPort)
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { return }
            connection.start(queue: self.queue)
            self.receive(on: connection, onDatagram: onDatagram)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        listener?.cancel()
        listener = nil
    }

    private func receive(on connection: NWConnection, onDatagram: @escaping ([UInt8]) -> Void) {
        connection.receiveMessage { [weak self] data, _, _, error in
            if let data, !data.isEmpty {
                onDatagram(Array(data))
            }
            guard error == nil else {
                connection.cancel()
                return
            }
            self?.receive(on: connection, onDatagram: onDatagram)
        }
    }
}
