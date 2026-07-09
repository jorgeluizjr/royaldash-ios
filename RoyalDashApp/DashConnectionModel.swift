import Foundation
import Combine
import RoyalDashCore

@MainActor
final class DashConnectionModel: ObservableObject {
    @Published private(set) var phase: DashConnectionPhase = .offline
    @Published var mode: DashConnectionMode = .simulated
    @Published private(set) var packetCount = 0
    @Published private(set) var lastEvent = "Aguardando acao"
    @Published private(set) var controlStatus = "--"
    @Published private(set) var rtpStatus = "--"

    private var peer = RecordingDatagramPeer()
    private var session: DashSession<RecordingDatagramPeer>?
    private var fakeDash = FakeDashSession()
    private var liveRuntime: LiveDashRuntime?

    func advance() {
        do {
            switch mode {
            case .simulated:
                try advanceSimulated()
            case .live:
                try advanceLive()
            }
        } catch {
            phase = .failed(error.localizedDescription)
            lastEvent = mode == .simulated ? "Erro no fluxo simulado" : "Erro no fluxo real"
        }
    }

    func setMode(_ mode: DashConnectionMode) {
        guard self.mode != mode else { return }
        disconnect()
        self.mode = mode
        lastEvent = mode == .simulated ? "Modo simulado ativo" : "Modo real preparado"
    }

    private func advanceSimulated() throws {
        switch phase {
        case .offline, .failed:
            connectWifi()
        case .wifi:
            try startAuthentication()
        case .authenticating:
            try confirmAuthenticationAndStartStream()
        case .streaming:
            disconnect()
        }
    }

    private func advanceLive() throws {
        switch phase {
        case .offline, .failed:
            prepareLiveRuntime()
        case .wifi:
            try liveRuntime?.startAuthentication()
        case .authenticating:
            try liveRuntime?.startProjectionProbe()
        case .streaming:
            disconnect()
        }
    }

    private func connectWifi() {
        fakeDash = FakeDashSession()
        peer = RecordingDatagramPeer()
        session = nil
        phase = .wifi
        packetCount = 0
        controlStatus = "Rede"
        rtpStatus = "--"
        lastEvent = "Wi-Fi do painel simulado"
    }

    private func startAuthentication() throws {
        var session = DashSession(
            ssid: "RE_HIMALAYAN_450",
            config: .loopbackFakeDash,
            peer: peer,
            keyGenerator: { [UInt8](repeating: 0x11, count: 32) },
            encryptor: { _, _, _ in [UInt8](repeating: 0x42, count: 128) }
        )

        try session.startAuthentication()
        let offeredKey = fakeDash.receiveControl(peer.sent.last?.bytes ?? [])
        for packet in offeredKey.packets {
            _ = try session.handleIncomingDatagram(packet)
        }

        self.session = session
        phase = .authenticating
        packetCount = peer.sent.count
        controlStatus = "Auth"
        rtpStatus = "--"
        lastEvent = "Chave RSA recebida e AES enviada"
    }

    private func confirmAuthenticationAndStartStream() throws {
        guard var session else {
            connectWifi()
            return
        }

        let confirmed = fakeDash.receiveControl(peer.sent.last?.bytes ?? [])
        for packet in confirmed.packets {
            _ = try session.handleIncomingDatagram(packet)
        }

        try session.sendProjectionFrame()
        try session.sendRtp([0x80, 0xE0, 0x00, 0x01, 0x00, 0x00, 0x0E, 0x10, 0x10, 0x20, 0x30, 0x40, 0x65, 0x88])

        self.session = session
        phase = .streaming
        packetCount = peer.sent.count
        controlStatus = "OK"
        rtpStatus = "4 fps"
        lastEvent = "Auth confirmada e frame RTP enviado"
    }

    private func disconnect() {
        session = nil
        fakeDash = FakeDashSession()
        liveRuntime?.stop()
        liveRuntime = nil
        phase = .offline
        packetCount = 0
        controlStatus = "--"
        rtpStatus = "--"
        lastEvent = "Sessao encerrada"
    }

    private func prepareLiveRuntime() {
        let runtime = LiveDashRuntime()
        runtime.onUpdate = { [weak self] update in
            Task { @MainActor in
                self?.apply(update)
            }
        }
        liveRuntime = runtime
        runtime.prepare()
    }

    private func apply(_ update: LiveDashRuntimeUpdate) {
        phase = update.phase
        packetCount = update.packetCount
        controlStatus = update.controlStatus
        rtpStatus = update.rtpStatus
        lastEvent = update.lastEvent
    }
}

enum DashConnectionMode: String, CaseIterable, Identifiable {
    case simulated
    case live

    var id: String { rawValue }

    var title: String {
        switch self {
        case .simulated:
            return "Simulado"
        case .live:
            return "TFT real"
        }
    }
}

enum DashConnectionPhase: Equatable {
    case offline
    case wifi
    case authenticating
    case streaming
    case failed(String)
}
