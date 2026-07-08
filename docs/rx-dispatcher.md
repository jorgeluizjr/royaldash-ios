# RX Dispatcher

`DashIncomingDispatcher` e a logica pura do receive loop do painel.

Ele recebe um datagrama K1G vindo do TFT, parseia os TLVs e devolve:

- pacotes de resposta que devem voltar pelo plano de controle;
- eventos que a sessao/app pode observar.

## Comportamentos cobertos

- `07 00` e `07 03`: alimentam `DashAuth`; quando as duas partes da chave publica chegam, devolve `q3c.d`.
- `07 01 01`: confirma autenticacao.
- `07 01 != 01`: reseta auth e devolve novo `authRequest` ate o limite de retry.
- `09 06 55`: devolve `frameDecodedIdr`.
- `09 04 55`: devolve `frameDecodedP`.
- `09 00 ... code`: devolve `buttonAck(code)` e publica evento de botao.
- TLVs desconhecidos: publica evento `unknown` sem resposta.

## Receive loop

`DashReceiveLoop` conecta o dispatcher ao transporte:

- passa cada datagrama recebido para `DashIncomingDispatcher`;
- envia cada reply com `DashTransport.sendControl(...)`;
- devolve os eventos para a futura `DashSession`.

## Proximo passo

Criar a sessao real:

1. Abrir `NetworkUdpReceiver` em `:2002` antes do burst inicial.
2. Enviar `DashCommands.initialBurst(...)` quando essa lista existir no core.
3. Ligar eventos do `DashReceiveLoop` ao estado da sessao.
