# UDP Transport

A camada inicial de transporte separa o protocolo da rede real.

## Endpoints congelados

Modo painel real:

- Controle TX: `192.168.1.255:2000`
- Controle local: `:2000`
- Controle RX: `:2002`
- RTP: `192.168.1.1:5000`

Modo fake dash:

- Controle TX: `127.0.0.1:2000`
- Controle RX: `:2002`
- RTP: `127.0.0.1:5000`

## O que ja existe

- `DashTransportConfig.tripperDash`
- `DashTransportConfig.loopbackFakeDash`
- `DashTransport.sendControl(...)`
- `DashTransport.sendRtp(...)`
- patch automatico do rolling sequence K1G nos pacotes de controle
- `RecordingDatagramPeer` para testes
- `NetworkUdpPeer` para envio UDP via `Network.framework`

## Proximo incremento

Ainda falta a parte mais sensivel: socket RX bindado em `:2002` antes do burst inicial e, depois, um loop de recebimento que alimente `DashAuth`, ACKs de frame e eventos de botao.
