# App Core Model

`DashConnectionModel` liga o prototipo SwiftUI ao `RoyalDashCore` em modo simulado e tambem prepara um modo real inicial para teste com o TFT.

No modo simulado ele usa:

- `DashSession` para iniciar auth, processar datagramas e enviar controle/RTP;
- `FakeDashSession` para simular respostas do painel;
- `RecordingDatagramPeer` para contar os pacotes enviados sem rede real.

## Fluxo do botao principal

1. `Offline` -> simula Wi-Fi do painel encontrado.
2. `Wi-Fi` -> chama `DashSession.startAuthentication()`, recebe chave publica fake e envia chave AES cifrada fake.
3. `Autenticando` -> confirma auth, envia `projectionFrame` e um pacote RTP de amostra.
4. `Transmitindo` -> encerra a sessao simulada.

## Modo TFT real

O modo `TFT real` usa `LiveDashRuntime`, que encapsula:

- `NetworkUdpPeer` para envio UDP;
- `NetworkUdpReceiver` na porta local de recepcao configurada;
- `DashSession` com a configuracao `.tripperDashUnicastControl`, que envia controle direto para `192.168.1.1:2000`.
- porta local `2000` fixada para o envio de controle.

O envio unicast e usado no app porque o envio UDP para broadcast (`192.168.1.255`) pode falhar no iOS com erro generico do `Network.framework`.

Fluxo esperado para o primeiro teste no iPhone:

1. Conectar manualmente o iPhone ao Wi-Fi do TFT.
2. Selecionar `TFT real` no app.
3. Tocar em `Conectar` para preparar o runtime.
4. Tocar em `Autenticar` para enviar o auth request e ouvir respostas.
5. Tocar em `Iniciar Stream` para enviar um frame/RTP de prova.

Essa etapa envia um unico frame H.264 de teste gerado com `VideoToolbox`, no tamanho 526 x 300, packetizado em RTP. Ainda nao e um stream continuo da UI; o objetivo e validar se o TFT decodifica um frame real sem deixar nada permanente no painel.
