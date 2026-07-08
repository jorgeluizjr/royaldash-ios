# GitHub Actions para o app iOS

Vamos usar GitHub Actions como build remoto de Xcode. A ideia e simples:

1. O codigo fica no GitHub.
2. Cada push roda em um runner macOS com Xcode.
3. O runner compila e testa o app em um simulador de iPhone disponivel no macOS do GitHub Actions.
4. O iPhone fisico continua sendo usado para validar o painel TFT real.

## Arquivo criado

Workflow:

- `.github/workflows/ios-ci.yml`

Ele esta preparado para:

- Rodar em `push`, `pull_request` e manualmente por `workflow_dispatch`.
- Usar `macos-latest`.
- Compilar `RoyalDash.xcodeproj`.
- Usar o scheme `RoyalDash`.
- Testar no simulador configurado em `SIMULATOR_DESTINATION`.
- Desativar assinatura no build de simulador com `CODE_SIGNING_ALLOWED=NO`.

Enquanto o projeto Xcode ainda nao existir, o workflow apenas informa isso e encerra sem erro.

## Quando criarmos o app

O projeto Xcode deve seguir estes nomes para funcionar sem ajuste:

- Projeto: `RoyalDash.xcodeproj`
- Scheme: `RoyalDash`

Se escolhermos outro nome, basta alterar no topo do workflow:

```yaml
env:
  XCODE_PROJECT: RoyalDash.xcodeproj
  XCODE_SCHEME: RoyalDash
```

## Repositorio publico ou privado

Para custo zero, o melhor caminho e usar um repositorio publico. GitHub Actions e gratuito para repositorios publicos em runners padrao. Em repositorio privado, a conta Free tem cota mensal, e runner macOS consome mais rapido que Linux.

## Limites

GitHub Actions compila e roda testes, mas nao substitui:

- Teste no iPhone 15 fisico.
- Conexao Wi-Fi com o TFT.
- UDP broadcast real.
- H.264/RTP no painel.
- Teste com tela bloqueada.
- Medicao de bateria/aquecimento.

Para instalar builds no iPhone por TestFlight ou distribuir fora do Mac local, precisaremos de assinatura Apple. O caminho mais limpo e Apple Developer Program quando chegarmos no primeiro build instalavel.

## Proximo passo recomendado

Criar o esqueleto SwiftUI nativo:

- `RoyalDash.xcodeproj`
- app `RoyalDash`
- modulo `DashProtocol`
- testes unitarios para K1G, comandos, auth e RTP
- tela inicial com estado `Offline / Wi-Fi / Auth / Streaming`

Depois disso, cada push ja sera validado pelo GitHub Actions.
