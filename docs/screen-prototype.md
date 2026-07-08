# Screen Prototype

O app agora tem um prototipo SwiftUI navegavel para orientar produto e fluxo.
Tambem existe um prototipo visual estatico em `docs/prototype.html`, que pode ser aberto direto no navegador sem Xcode.

## Telas

- **Painel**: estado de conexao, acao principal, preview TFT 526 x 300, metricas, rota e diagnostico UDP/RTP.
- **Rotas**: destino selecionado, acoes de rota, destinos salvos.
- **Moto**: odometro, proxima revisao, manutencao e checklist pre-ride.
- **Custos**: resumo mensal, atalhos de lancamento e despesas recentes.
- **Ajustes**: SSID, senha, portas, permissoes e diagnostico.

## Observacao

Esse prototipo ainda nao conecta ao painel real. O botao principal apenas alterna estados simulados: `Offline`, `Wi-Fi`, `Autenticando` e `Transmitindo`.

O objetivo e validar a ideia visual e o fluxo antes de ligar a UI ao `RoyalDashCore` e aos sockets reais.
