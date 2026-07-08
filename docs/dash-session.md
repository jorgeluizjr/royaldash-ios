# Dash Session

`DashSession` e a fachada de alto nivel para o app iOS.

Ela compoe as pecas que ja existem:

1. `DashAuth` para handshake RSA/AES;
2. `DashIncomingDispatcher` para interpretar TLVs recebidos;
3. `DashReceiveLoop` para enviar respostas obrigatorias;
4. `DashTransport` para controle UDP e RTP.

## Fluxo atual

O uso esperado no app e:

1. abrir o socket RX em `DashTransportConfig.receiveLocalPort`;
2. criar uma `DashSession`;
3. chamar `startAuthentication()`;
4. alimentar cada datagrama recebido em `handleIncomingDatagram(_:)`;
5. observar `state` e os `DashIncomingEvent` retornados.

Essa camada ainda nao cria sockets por conta propria. Isso mantem os testes deterministas e deixa o app SwiftUI controlar ciclo de vida, permissoes de rede local e pareamento Wi-Fi.

## Estado

`DashSessionState` cobre o minimo para o shell do app:

- `idle`
- `authenticating`
- `authenticated`
- `failed(reason:)`

Estados de streaming e navegacao devem ser adicionados quando o encoder H.264 e a sequencia de entrada em navegacao estiverem implementados.
