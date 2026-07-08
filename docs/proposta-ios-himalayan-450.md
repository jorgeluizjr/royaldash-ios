# Proposta de App iOS para Himalayan 450 TFT

## Leitura do open-dash

O `subtlesayak/open-dash` e um app Android companion para o painel Tripper/TFT: navegacao, historico de viagens, garagem, despesas, wallpapers e cartoes de midia/chamada. O ponto central nao e espelhamento de tela; o app renderiza uma tela propria off-screen, codifica H.264 e transmite por Wi-Fi para manter a tela do telefone apagada durante a pilotagem.

O protocolo do painel e nao oficial e foi obtido por engenharia reversa. A parte critica esta documentada no `docs/PROTOCOL_FREEZE.md` e nos arquivos:

- `DashSession.kt`
- `DashSocket.kt`
- `DashAuth.kt`
- `DashCommands.kt`
- `K1GPacket.kt`
- `DashEncoder.kt`
- `NalProcessor.kt`
- `RtpPacketizer.kt`

## O que precisa ser preservado no iPhone

O app iOS nao deve tentar "adaptar" o protocolo. Ele deve reproduzir a sequencia e os bytes atuais:

- Abrir RX antes do primeiro pacote.
- Controle UDP TX local `:2000` para broadcast `192.168.1.255:2000`.
- Controle UDP RX local `:2002`.
- RTP/H.264 para `192.168.1.1:5000`.
- Autenticacao RSA-1024 + chave AES-256 usando o SSID exato do painel.
- ACK obrigatorio para pacotes `09 06 55`, `09 04 55` e eventos de botao `09 00`.
- Sequencia de entrada em navegacao: `navContext`, listas vazias, route-card repetido, projection frame, placeholder, nav start, route-card com projecao ativa.
- H.264 AVC Baseline, 526 x 300, cerca de 2-4 fps, 200 kbps, SPS/PPS tratados do jeito esperado pelo painel.
- RTP payload type 96, clock 90 kHz, payload maximo 1380 bytes, fragmentacao FU-A e sem STAP-A.

## Viabilidade no iOS

E viavel criar um app iPhone equivalente, mas o risco maior nao e UI: e a combinacao de Wi-Fi controlado, UDP broadcast, stream H.264 e comportamento em background.

O iOS permite pedir conexao a uma rede Wi-Fi conhecida via `NEHotspotConfiguration`, mas nao oferece a mesma liberdade do Android para escanear e escolher qualquer SSID. Por isso, no MVP o usuario deve informar o SSID exato do painel ou parear por um fluxo guiado. Isso importa porque o painel valida o SSID dentro do handshake criptografado.

Para rede, eu usaria `Network.framework` quando possivel e cairia para sockets BSD se for necessario controlar melhor bind local, broadcast e portas fixas. O app precisara de permissao de rede local (`NSLocalNetworkUsageDescription`) e testes reais no painel para confirmar broadcast, bind `:2000/:2002` e recepcao constante.

Para video, o equivalente iOS natural e:

- Renderizacao: CoreGraphics/Metal em buffer off-screen 526 x 300.
- Encoder: VideoToolbox `VTCompressionSession`.
- Perfil: H.264 Baseline Level 4.1, 200 kbps, 4 fps, keyframe a cada 1 s.
- Pos-processamento: converter saida do VideoToolbox para NAL Annex-B, filtrar AUD/SEI, cachear SPS/PPS, normalizar SPS se o painel exigir e empacotar RTP.

## Produto proposto

Nome de trabalho: **RoyalDash iOS**.

Primeira tela: painel operacional, nao landing page. O usuario abre e ve:

- Estado da moto/painel: Offline, Wi-Fi, Autenticando, Pronto, Transmitindo, Erro.
- Botao principal: Conectar / Desconectar.
- Destino atual e ultimo destino.
- Status de GPS e rota.
- Atalhos para garagem, abastecimento, manutencao e historico.

Abas principais:

- **Painel**: conexao, rota, preview, stream, wallpapers.
- **Rotas**: destinos salvos, receber compartilhamento do Apple Maps/Google Maps, iniciar navegacao.
- **Garagem**: odometro, manutencao, corrente, oleo, pneus, freios.
- **Custos**: combustivel, revisoes, acessorios, viagens.
- **Historico**: viagens gravadas, distancia, tempo, mapa simplificado.
- **Ajustes**: SSID/senha, unidades, voz, privacidade, logs de diagnostico.

## Arquitetura iOS

Camadas:

- `DashProtocol`: K1G packet builder/parser, comandos, auth RSA/AES, ACKs.
- `DashTransport`: Wi-Fi pairing, UDP control sockets, UDP RTP socket, reconexao.
- `DashProjection`: renderer 526 x 300, VideoToolbox encoder, NAL processor, RTP packetizer.
- `Navigation`: parser de compartilhamento, OSRM/router, progresso de rota, ETA, off-route.
- `GarageData`: SwiftData ou SQLite/GRDB, local-first.
- `Sync`: CloudKit opcional, preferivel a Firebase para uma versao iOS nativa.
- `UI`: SwiftUI, com uma tela operacional densa e controles grandes para uso antes da pilotagem.

## Plano de execucao

### Fase 0 - Descoberta tecnica

Objetivo: reduzir risco antes de desenhar o app inteiro.

- Criar projeto Swift iOS minimal.
- Implementar `K1GPacket`, `DashCommands`, `DashAuth`.
- Conectar ao Wi-Fi informado manualmente.
- Abrir UDP `:2000`, `:2002` e RTP.
- Enviar initial burst.
- Confirmar auth `07 01 01`.
- Registrar logs seguros, sem SSID completo e sem coordenadas.

Criterio de sucesso: iPhone autentica com o painel real.

### Fase 1 - Stream minimo

- Gerar frame estatico 526 x 300.
- Codificar H.264 com VideoToolbox.
- Aplicar processamento de NAL/SPS/PPS.
- Enviar RTP para `192.168.1.1:5000`.
- Responder ACKs do painel enquanto transmite.

Criterio de sucesso: painel mostra imagem estavel por 10 minutos.

### Fase 2 - Navegacao funcional

- Receber destino compartilhado.
- Resolver coordenadas.
- Calcular rota via OSRM.
- Renderizar mapa raster/off-screen, ETA, distancia restante e marcador.
- Recalcular rota fora do trajeto.
- Voz por `AVSpeechSynthesizer` opcional.

Criterio de sucesso: uma rota real aparece e se atualiza no painel.

### Fase 3 - App de uso diario

- Garagem, manutencao e abastecimentos.
- Historico de viagens.
- Wallpapers.
- Exportacao CSV.
- CloudKit opcional.

### Fase 4 - Polimento e revisao

- Testes com firmware do painel.
- Logs de diagnostico exportaveis.
- Energia/temperatura.
- App Review hardening.
- Avisos de seguranca e modo sem interacao durante pilotagem.

## Principais riscos

- **SSID exato no iOS**: o Android descobre/resolve SSID; no iOS provavelmente teremos fluxo manual ou QR.
- **Background**: manter GPS, encoder e UDP com tela apagada pode ser limitado. O MVP deve medir isso cedo.
- **Broadcast UDP**: precisa validar no iPhone real, na rede do painel.
- **VideoToolbox**: a saida H.264 do iOS pode exigir normalizacao diferente da do Android.
- **Firmware**: o proprio open-dash alerta que comportamento real depende de firmware e hardware.
- **App Store**: protocolo nao oficial e controle de painel de moto pedem cuidado em privacidade, seguranca e disclaimers.

## Minha recomendacao

Construir como app nativo SwiftUI, nao multiplataforma. O core e baixo nivel demais para React Native/Flutter no MVP, principalmente por Wi-Fi, UDP, encoder e background. Depois que o protocolo estiver estavel, uma camada visual compartilhada poderia ser considerada, mas agora a prioridade e controle fino do iOS.

O primeiro marco nao deve ser "app completo"; deve ser **prova no painel real**:

1. iPhone conecta ao Wi-Fi do TFT.
2. Handshake autentica.
3. Painel recebe H.264/RTP.
4. Tela apagada nao derruba stream em poucos minutos.

Se esse marco passar, o app completo e uma construcao normal de produto. Se falhar, descobrimos cedo qual limite do iOS exige outra estrategia.

## Branches tecnicas iniciais

- `codex/fake-dash`: simulador offline do painel para validar pacotes sem a moto.
- `codex/dash-auth`: maquina de autenticacao RSA/AES do lado iOS.
- `codex/udp-transport`: roteamento dos datagramas UDP de controle/RTP e modo loopback para o fake dash.
- `codex/rx-dispatcher`: roteamento de TLVs recebidos, ACKs obrigatorios e retries de auth.
- `codex/rx-loop`: cola entre socket RX, dispatcher e transporte.
- `codex/dash-session`: fachada de sessao para o app iniciar auth, consumir eventos e enviar comandos/RTP.

## Fontes consultadas

- Repositorio Android: https://github.com/subtlesayak/open-dash
- Protocolo congelado: https://github.com/subtlesayak/open-dash/blob/main/docs/PROTOCOL_FREEZE.md
- Apple `NEHotspotConfiguration`: https://developer.apple.com/documentation/networkextension/nehotspotconfiguration
- Apple `NEHotspotConfigurationManager`: https://developer.apple.com/documentation/networkextension/nehotspotconfigurationmanager
- Apple `VTCompressionSession`: https://developer.apple.com/documentation/videotoolbox/vtcompressionsession
- Apple local network privacy: https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy
