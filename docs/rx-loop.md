# RX Loop

`DashReceiveLoop` e o elo entre rede e protocolo.

Ele fica abaixo de `DashSession` e faz o caminho essencial:

1. recebe um datagrama vindo do painel;
2. chama `DashIncomingDispatcher`;
3. envia cada resposta usando `DashTransport.sendControl(...)`;
4. devolve eventos para `DashSession` e para o app.

## Socket real

`NetworkUdpReceiver` usa `NWListener` UDP e pode escutar a porta `:2002`.

A ordem operacional futura deve ser:

1. criar o receiver em `DashTransportConfig.receiveLocalPort`;
2. iniciar o receiver;
3. so entao enviar o initial burst;
4. alimentar cada datagrama recebido no `DashReceiveLoop`.

Isso preserva a regra critica do protocolo: RX aberto antes do primeiro burst.
