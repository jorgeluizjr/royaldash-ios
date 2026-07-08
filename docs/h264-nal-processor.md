# H.264 NAL Processor

`H264NalProcessor` prepara a saida do futuro encoder iOS antes do RTP.

Ele cobre o comportamento que precisamos validar cedo:

- aceita NALs em Annex-B ou AVCC;
- remove AUD (`type 9`) e SEI (`type 6`);
- cacheia SPS (`type 7`) e PPS (`type 8`);
- injeta SPS/PPS antes de um IDR (`type 5`) quando o access unit nao trouxer esses parametros;
- devolve NALs crus, prontos para `RtpPacketizer`.

## Por que isso existe antes do VideoToolbox

O `VTCompressionSession` normalmente entrega amostras H.264 com comprimentos AVCC, enquanto o protocolo do painel e sensivel a SPS/PPS, IDR e empacotamento RTP. Separar essa logica agora permite testar as regras criticas sem depender de encoder, simulator ou painel real.

## Proximo encaixe

Quando o encoder entrar, o fluxo sera:

1. render 526 x 300 off-screen;
2. VideoToolbox gera H.264;
3. `H264NalProcessor` normaliza as NALs;
4. `RtpPacketizer` fragmenta em RTP;
5. `DashSession.sendRtp(_:)` envia para `192.168.1.1:5000`.
