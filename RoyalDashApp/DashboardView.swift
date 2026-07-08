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

            PlaceholderTab(title: "Rotas", systemImage: "map", primary: "Nenhuma rota ativa", secondary: "Destinos compartilhados vao aparecer aqui.")
                .tabItem {
                    Label("Rotas", systemImage: "map")
                }
                .tag(AppTab.routes)

            PlaceholderTab(title: "Garagem", systemImage: "wrench.and.screwdriver", primary: "Himalayan 450", secondary: "Manutencao, pneus e revisoes.")
                .tabItem {
                    Label("Garagem", systemImage: "wrench.and.screwdriver")
                }
                .tag(AppTab.garage)

            PlaceholderTab(title: "Custos", systemImage: "fuelpump", primary: "Sem lancamentos", secondary: "Combustivel e despesas da moto.")
                .tabItem {
                    Label("Custos", systemImage: "fuelpump")
                }
                .tag(AppTab.costs)
        }
        .tint(.teal)
    }
}

private struct PanelView: View {
    @Binding var connectionState: ConnectionState

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    StatusHeader(state: connectionState)

                    Button {
                        connectionState = connectionState == .offline ? .ready : .offline
                    } label: {
                        Label(connectionState == .offline ? "Conectar" : "Desconectar", systemImage: connectionState == .offline ? "wifi" : "xmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    MetricsGrid()

                    SectionPanel(title: "Destino") {
                        HStack(spacing: 12) {
                            Image(systemName: "location.north.line")
                                .font(.title2)
                                .foregroundStyle(.teal)
                                .frame(width: 36, height: 36)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Nenhum destino selecionado")
                                    .font(.headline)
                                Text("Aguardando rota")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    SectionPanel(title: "Stream") {
                        HStack {
                            Label("RTP inativo", systemImage: "video.slash")
                            Spacer()
                            Text("526 x 300")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("RoyalDash")
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
                StatusPill(title: "Wi-Fi", value: state == .offline ? "Off" : "TFT")
                StatusPill(title: "Auth", value: state == .ready ? "OK" : "--")
                StatusPill(title: "GPS", value: "Pronto")
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color(.tertiarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricsGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Painel", value: "Offline", symbol: "speedometer")
            MetricTile(title: "Pacotes", value: "0", symbol: "network")
            MetricTile(title: "Video", value: "0 fps", symbol: "rectangle.inset.filled")
            MetricTile(title: "Bateria", value: "--", symbol: "iphone")
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

private struct PlaceholderTab: View {
    let title: String
    let systemImage: String
    let primary: String
    let secondary: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(.teal)
                Text(primary)
                    .font(.title3.weight(.semibold))
                Text(secondary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
            .background(Color(.systemGroupedBackground))
            .navigationTitle(title)
        }
    }
}

private enum AppTab {
    case panel
    case routes
    case garage
    case costs
}

private enum ConnectionState {
    case offline
    case ready

    var title: String {
        switch self {
        case .offline:
            return "Offline"
        case .ready:
            return "Pronto"
        }
    }

    var detail: String {
        switch self {
        case .offline:
            return "TFT desconectado"
        case .ready:
            return "Sessao pronta para stream"
        }
    }

    var symbol: String {
        switch self {
        case .offline:
            return "wifi.slash"
        case .ready:
            return "checkmark.seal"
        }
    }

    var color: Color {
        switch self {
        case .offline:
            return .orange
        case .ready:
            return .teal
        }
    }
}

#Preview {
    DashboardView()
}
