# App Core Model

`DashConnectionModel` liga o prototipo SwiftUI ao `RoyalDashCore` em modo simulado.

O modelo ainda nao abre sockets reais. Ele usa:

- `DashSession` para iniciar auth, processar datagramas e enviar controle/RTP;
- `FakeDashSession` para simular respostas do painel;
- `RecordingDatagramPeer` para contar os pacotes enviados sem rede real.

## Fluxo do botao principal

1. `Offline` -> simula Wi-Fi do painel encontrado.
2. `Wi-Fi` -> chama `DashSession.startAuthentication()`, recebe chave publica fake e envia chave AES cifrada fake.
3. `Autenticando` -> confirma auth, envia `projectionFrame` e um pacote RTP de amostra.
4. `Transmitindo` -> encerra a sessao simulada.

Essa etapa prepara a futura troca do fake dash por `NetworkUdpReceiver` e `NetworkUdpPeer` sem redesenhar a UI.
