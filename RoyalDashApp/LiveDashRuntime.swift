import Foundation
import RoyalDashCore

struct LiveDashRuntimeUpdate {
    let phase: DashConnectionPhase
    let packetCount: Int
    let controlStatus: String
    let rtpStatus: String
    let lastEvent: String
}

final class LiveDashRuntime {
    var onUpdate: ((LiveDashRuntimeUpdate) -> Void)?

    private let peer: CountingDatagramPeer
    private let receiver: NetworkUdpReceiver
    private var session: DashSession<CountingDatagramPeer>
    private let testPatternEncoder = H264TestPatternEncoder()
    private var isReceiverStarted = false

    init(
        ssid: String = "RE_HIMALAYAN_450",
        config: DashTransportConfig = .tripperDashUnicastControl
    ) {
        let peer = CountingDatagramPeer(localPort: config.controlLocalPort)
        self.peer = peer
        self.receiver = NetworkUdpReceiver(port: config.receiveLocalPort)
        self.session = DashSession(
            ssid: ssid,
            config: config,
            peer: peer
        )
    }

    func prepare() {
        publish(
            phase: .wifi,
            controlStatus: "Pronto",
            rtpStatus: "--",
            lastEvent: "Conecte o iPhone ao Wi-Fi do TFT e autentique"
        )
    }

    func startAuthentication() throws {
        try startReceiverIfNeeded()
        try session.startAuthentication()
        publish(
            phase: .authenticating,
            controlStatus: "Auth",
            rtpStatus: "--",
            lastEvent: "Auth request enviado para o TFT"
        )
    }

    func startProjectionProbe() throws {
        try session.sendProjectionFrame()
        let packets = try testPatternEncoder.makeRtpPackets()
        for packet in packets {
            try session.sendRtp(packet)
        }
        publish(
            phase: .streaming,
            controlStatus: "OK",
            rtpStatus: "\(packets.count) RTP",
            lastEvent: "Frame H.264 de teste enviado ao TFT"
        )
    }

    func stop() {
        receiver.stop()
        isReceiverStarted = false
    }

    private func startReceiverIfNeeded() throws {
        guard !isReceiverStarted else { return }
        try receiver.start { [weak self] datagram in
            self?.handleIncomingDatagram(datagram)
        }
        isReceiverStarted = true
    }

    private func handleIncomingDatagram(_ datagram: [UInt8]) {
        do {
            let events = try session.handleIncomingDatagram(datagram)
            publish(events: events)
        } catch {
            publish(
                phase: .failed("Falha RX: \(error.localizedDescription)"),
                controlStatus: "Erro",
                rtpStatus: "--",
                lastEvent: "Erro ao processar datagrama recebido"
            )
        }
    }

    private func publish(events: [DashIncomingEvent]) {
        guard let event = events.last else {
            publish(
                phase: .authenticating,
                controlStatus: "RX",
                rtpStatus: "--",
                lastEvent: "Datagrama recebido sem evento de app"
            )
            return
        }

        switch event {
        case .authKeyRequested:
            publish(
                phase: .authenticating,
                controlStatus: "RSA",
                rtpStatus: "--",
                lastEvent: "Chave publica recebida; AES enviada"
            )
        case .authConfirmed:
            publish(
                phase: .authenticating,
                controlStatus: "OK",
                rtpStatus: "--",
                lastEvent: "Auth confirmada; pronto para iniciar stream"
            )
        case .authRejected(let retry, let willRetry):
            publish(
                phase: willRetry ? .authenticating : .failed("Auth rejeitada pelo TFT"),
                controlStatus: "Retry \(retry)",
                rtpStatus: "--",
                lastEvent: willRetry ? "TFT pediu nova tentativa de auth" : "Limite de auth atingido"
            )
        case .frameDecoded(kind: _):
            publish(
                phase: .streaming,
                controlStatus: "OK",
                rtpStatus: "ACK",
                lastEvent: "TFT confirmou frame"
            )
        case .button(code: let code):
            publish(
                phase: .streaming,
                controlStatus: "Botao",
                rtpStatus: "ACK",
                lastEvent: "Botao recebido: \(code)"
            )
        case .unknown(tlv: _):
            publish(
                phase: .authenticating,
                controlStatus: "RX",
                rtpStatus: "--",
                lastEvent: "Evento desconhecido recebido"
            )
        }
    }

    private func publish(
        phase: DashConnectionPhase,
        controlStatus: String,
        rtpStatus: String,
        lastEvent: String
    ) {
        let update = LiveDashRuntimeUpdate(
            phase: phase,
            packetCount: peer.packetCount,
            controlStatus: controlStatus,
            rtpStatus: rtpStatus,
            lastEvent: lastEvent
        )

        DispatchQueue.main.async { [onUpdate] in
            onUpdate?(update)
        }
    }
}

private final class CountingDatagramPeer: DatagramPeer {
    private let networkPeer: NetworkUdpPeer
    private(set) var packetCount = 0

    init(localPort: UInt16? = nil) {
        self.networkPeer = NetworkUdpPeer(localPort: localPort)
    }

    func send(_ bytes: [UInt8], to endpoint: UdpEndpoint) throws {
        try networkPeer.send(bytes, to: endpoint)
        packetCount += 1
    }
}
