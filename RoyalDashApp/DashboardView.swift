import SwiftUI

struct DashboardView: View {
    @State private var connectionState: ConnectionState = .offline
    @State private var selectedTab: AppTab = .panel

    var body: some View {
        TabView(selection: $selectedTab) {
            PanelView(connectionState: $connectionState)
                .tabItem {
                    Label("Painel", systemImage: "motorcycle")
                }
                .tag(AppTab.panel)

            RoutesView()
                .tabItem {
                    Label("Rotas", systemImage: "map")
                }
                .tag(AppTab.routes)

            GarageView()
                .tabItem {
                    Label("Moto", systemImage: "wrench.and.screwdriver")
                }
                .tag(AppTab.garage)

            CostsView()
                .tabItem {
                    Label("Custos", systemImage: "fuelpump")
                }
                .tag(AppTab.costs)

            SettingsView()
                .tabItem {
                    Label("Ajustes", systemImage: "gearshape")
                }
                .tag(AppTab.settings)
        }
        .tint(.teal)
    }
}

private struct PanelView: View {
    @Binding var connectionState: ConnectionState

    var body: some View {
        PrototypeScreen(title: "RoyalDash") {
            StatusHeader(state: connectionState)

            Button {
                connectionState.advance()
            } label: {
                Label(connectionState.actionTitle, systemImage: connectionState.actionSymbol)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            TftPreviewCard(state: connectionState)

            MetricsGrid(state: connectionState)

            SectionPanel(title: "Rota atual") {
                InfoRow(symbol: "location.north.line", title: "Serra do Rastro", subtitle: "126 km restantes", accessory: "2h 18m")
                Divider()
                InfoRow(symbol: "arrow.triangle.turn.up.right.diamond", title: "Proxima instrucao", subtitle: "Direita em 800 m", accessory: "BR-282")
            }

            SectionPanel(title: "Diagnostico rapido") {
                InfoRow(symbol: "antenna.radiowaves.left.and.right", title: "Controle UDP", subtitle: "TX :2000 / RX :2002", accessory: connectionState == .offline ? "--" : "OK")
                Divider()
                InfoRow(symbol: "video", title: "RTP H.264", subtitle: "Destino 192.168.1.1:5000", accessory: connectionState == .streaming ? "Ativo" : "Parado")
            }
        }
    }
}

private struct RoutesView: View {
    var body: some View {
        PrototypeScreen(title: "Rotas") {
            SectionPanel(title: "Destino selecionado") {
                InfoRow(symbol: "flag.checkered", title: "Mirante da Serra", subtitle: "Estrada cenario - 186 km", accessory: "Favorito")
                Divider()
                ProgressStrip(title: "Progresso simulado", value: 0.34, footer: "64 km percorridos")
            }

            SectionPanel(title: "Acoes") {
                ActionGrid(actions: [
                    PrototypeAction(symbol: "square.and.arrow.down", title: "Receber mapa", subtitle: "Apple/Google"),
                    PrototypeAction(symbol: "magnifyingglass", title: "Buscar", subtitle: "Endereco"),
                    PrototypeAction(symbol: "point.topleft.down.curvedto.point.bottomright.up", title: "Recalcular", subtitle: "OSRM"),
                    PrototypeAction(symbol: "speaker.wave.2", title: "Voz", subtitle: "Ativar"),
                ])
            }

            SectionPanel(title: "Destinos salvos") {
                InfoRow(symbol: "house", title: "Casa", subtitle: "Ultimo uso ontem", accessory: "12 km")
                Divider()
                InfoRow(symbol: "briefcase", title: "Trabalho", subtitle: "Rota urbana", accessory: "22 km")
                Divider()
                InfoRow(symbol: "mountain.2", title: "Campos do Jordao", subtitle: "Viagem fim de semana", accessory: "172 km")
            }
        }
    }
}

private struct GarageView: View {
    var body: some View {
        PrototypeScreen(title: "Moto") {
            SectionPanel(title: "Himalayan 450") {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: "motorcycle")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.teal)
                        .frame(width: 72, height: 72)
                        .background(Color.teal.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Royal Enfield Himalayan 450")
                            .font(.headline)
                        Text("Odometro 4.820 km")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProgressStrip(title: "Proxima revisao", value: 0.58, footer: "1.180 km restantes")
                    }
                }
            }

            SectionPanel(title: "Manutencao") {
                InfoRow(symbol: "drop", title: "Oleo do motor", subtitle: "Troca em 1.180 km", accessory: "OK")
                Divider()
                InfoRow(symbol: "circle.dashed", title: "Corrente", subtitle: "Lubrificar em 220 km", accessory: "Logo")
                Divider()
                InfoRow(symbol: "gauge.with.dots.needle.bottom.50percent", title: "Pneus", subtitle: "Calibragem semanal", accessory: "32/36")
            }

            SectionPanel(title: "Checklist pre-ride") {
                ChecklistRow(title: "Combustivel acima de 1/4", checked: true)
                ChecklistRow(title: "Pneus calibrados", checked: true)
                ChecklistRow(title: "Rota carregada no painel", checked: false)
            }
        }
    }
}

private struct CostsView: View {
    var body: some View {
        PrototypeScreen(title: "Custos") {
            SectionPanel(title: "Resumo do mes") {
                HStack(spacing: 12) {
                    MoneyTile(title: "Total", value: "R$ 486")
                    MoneyTile(title: "Combustivel", value: "R$ 214")
                    MoneyTile(title: "Media", value: "28 km/l")
                }
            }

            SectionPanel(title: "Adicionar") {
                ActionGrid(actions: [
                    PrototypeAction(symbol: "fuelpump", title: "Abastecer", subtitle: "Litros/km"),
                    PrototypeAction(symbol: "wrench.adjustable", title: "Servico", subtitle: "Oficina"),
                    PrototypeAction(symbol: "bag", title: "Acessorio", subtitle: "Peca"),
                    PrototypeAction(symbol: "doc.text", title: "Exportar", subtitle: "CSV"),
                ])
            }

            SectionPanel(title: "Lancamentos recentes") {
                InfoRow(symbol: "fuelpump", title: "Gasolina", subtitle: "11,2 L - Posto Centro", accessory: "R$ 67")
                Divider()
                InfoRow(symbol: "wrench.and.screwdriver", title: "Lubrificante corrente", subtitle: "Manutencao", accessory: "R$ 48")
                Divider()
                InfoRow(symbol: "shield", title: "Protetor de mao", subtitle: "Acessorio", accessory: "R$ 186")
            }
        }
    }
}

private struct SettingsView: View {
    var body: some View {
        PrototypeScreen(title: "Ajustes") {
            SectionPanel(title: "Painel TFT") {
                InfoRow(symbol: "wifi", title: "SSID", subtitle: "RE_HIMALAYAN_450", accessory: "Editar")
                Divider()
                InfoRow(symbol: "lock", title: "Senha Wi-Fi", subtitle: "Salva no dispositivo", accessory: "OK")
                Divider()
                InfoRow(symbol: "network", title: "Portas", subtitle: "Controle 2000/2002 - RTP 5000", accessory: "Padrao")
            }

            SectionPanel(title: "Permissoes") {
                ChecklistRow(title: "Rede local", checked: true)
                ChecklistRow(title: "Localizacao durante rota", checked: true)
                ChecklistRow(title: "Manter tela apagada em teste", checked: false)
            }

            SectionPanel(title: "Diagnostico") {
                InfoRow(symbol: "ladybug", title: "Logs seguros", subtitle: "Sem coordenadas precisas", accessory: "Ativo")
                Divider()
                InfoRow(symbol: "square.and.arrow.up", title: "Exportar pacote", subtitle: "Eventos de protocolo", accessory: "ZIP")
            }
        }
    }
}

private struct PrototypeScreen<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
        }
    }
}

private struct StatusHeader: View {
    let state: ConnectionState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: state.symbol)
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(state.color)
                    .frame(width: 52, height: 52)
                    .background(state.color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(state.title)
                        .font(.title2.weight(.semibold))
                    Text(state.detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 10) {
                StatusPill(title: "Wi-Fi", value: state.wifiValue)
                StatusPill(title: "Auth", value: state.authValue)
                StatusPill(title: "Stream", value: state.streamValue)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TftPreviewCard: View {
    let state: ConnectionState

    var body: some View {
        SectionPanel(title: "Preview TFT") {
            VStack(alignment: .leading, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(colors: [.black, .teal.opacity(0.55)], startPoint: .topLeading, endPoint: .bottomTrailing))

                    VStack(spacing: 10) {
                        HStack {
                            Text("126 km")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                            Spacer()
                            Text("2h18")
                                .font(.system(size: 22, weight: .semibold, design: .rounded))
                        }
                        Spacer()
                        HStack {
                            Image(systemName: "arrow.turn.up.right")
                                .font(.system(size: 34, weight: .bold))
                            VStack(alignment: .leading) {
                                Text("800 m")
                                    .font(.headline)
                                Text("BR-282")
                                    .font(.caption)
                            }
                            Spacer()
                            Text(state == .streaming ? "LIVE" : "IDLE")
                                .font(.caption.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(state.color, in: Capsule())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                }
                .aspectRatio(526.0 / 300.0, contentMode: .fit)

                Text("Prototipo visual do frame 526 x 300 que sera enviado ao painel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct StatusPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricsGrid: View {
    let state: ConnectionState

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Painel", value: state.title, symbol: "speedometer")
            MetricTile(title: "Pacotes", value: state == .offline ? "0" : "128", symbol: "network")
            MetricTile(title: "Video", value: state == .streaming ? "4 fps" : "0 fps", symbol: "rectangle.inset.filled")
            MetricTile(title: "Bateria", value: "92%", symbol: "iphone")
        }
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(.teal)
            Text(value)
                .font(.title3.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SectionPanel<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct InfoRow: View {
    let symbol: String
    let title: String
    let subtitle: String
    let accessory: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.teal)
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(accessory)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

private struct ChecklistRow: View {
    let title: String
    let checked: Bool

    var body: some View {
        HStack {
            Label(title, systemImage: checked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(checked ? .primary : .secondary)
            Spacer()
        }
        .font(.subheadline)
        .padding(.vertical, 3)
    }
}

private struct ProgressStrip: View {
    let title: String
    let value: Double
    let footer: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: value)
                .tint(.teal)
            Text(footer)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ActionGrid: View {
    let actions: [PrototypeAction]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(actions) { action in
                Button {} label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: action.symbol)
                            .font(.title3)
                        Text(action.title)
                            .font(.subheadline.weight(.semibold))
                        Text(action.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
                    .padding()
                }
                .buttonStyle(.bordered)
                .tint(.teal)
            }
        }
    }
}

private struct MoneyTile: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PrototypeAction: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let subtitle: String
}

private enum AppTab {
    case panel
    case routes
    case garage
    case costs
    case settings
}

private enum ConnectionState {
    case offline
    case wifi
    case authenticating
    case streaming

    mutating func advance() {
        switch self {
        case .offline:
            self = .wifi
        case .wifi:
            self = .authenticating
        case .authenticating:
            self = .streaming
        case .streaming:
            self = .offline
        }
    }

    var title: String {
        switch self {
        case .offline:
            return "Offline"
        case .wifi:
            return "Wi-Fi"
        case .authenticating:
            return "Autenticando"
        case .streaming:
            return "Transmitindo"
        }
    }

    var detail: String {
        switch self {
        case .offline:
            return "TFT desconectado"
        case .wifi:
            return "Rede do painel encontrada"
        case .authenticating:
            return "Handshake RSA/AES em andamento"
        case .streaming:
            return "RTP H.264 ativo"
        }
    }

    var actionTitle: String {
        switch self {
        case .offline:
            return "Conectar"
        case .wifi:
            return "Autenticar"
        case .authenticating:
            return "Iniciar Stream"
        case .streaming:
            return "Desconectar"
        }
    }

    var actionSymbol: String {
        switch self {
        case .offline:
            return "wifi"
        case .wifi:
            return "lock.open"
        case .authenticating:
            return "play.circle"
        case .streaming:
            return "xmark.circle"
        }
    }

    var symbol: String {
        switch self {
        case .offline:
            return "wifi.slash"
        case .wifi:
            return "wifi"
        case .authenticating:
            return "lock.rotation"
        case .streaming:
            return "dot.radiowaves.left.and.right"
        }
    }

    var color: Color {
        switch self {
        case .offline:
            return .orange
        case .wifi:
            return .blue
        case .authenticating:
            return .purple
        case .streaming:
            return .teal
        }
    }

    var wifiValue: String {
        self == .offline ? "Off" : "TFT"
    }

    var authValue: String {
        switch self {
        case .offline, .wifi:
            return "--"
        case .authenticating:
            return "RSA"
        case .streaming:
            return "OK"
        }
    }

    var streamValue: String {
        self == .streaming ? "4 fps" : "--"
    }
}

#Preview {
    DashboardView()
}
