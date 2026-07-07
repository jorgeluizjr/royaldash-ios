# Fake Dash

`RoyalDashFakeDash` e um simulador offline do painel TFT para testar a logica de protocolo antes de depender da moto.

Ele ainda nao abre sockets UDP. A primeira versao e propositalmente pura:

- recebe pacotes K1G de controle;
- reconhece `authRequest`;
- devolve TLVs fake de chave publica RSA (`07 00` e `07 03`);
- reconhece `authSendKey` com ciphertext de 128 bytes;
- devolve confirmacao `07 01 01`;
- gera notificacoes de frame decodificado `09 06 55` e `09 04 55`;
- gera evento de botao `09 00`;
- observa cabecalho RTP e registra sequencia, timestamp, marker bit e tamanho de payload.

## Rodar localmente em macOS

```bash
swift run royaldash-fake-dash
```

No Windows desta workspace nao ha toolchain Swift instalada, entao a validacao automatica acontece no GitHub Actions.

## Proximo passo

Depois que o transporte iOS/macOS existir, este fake dash deve ganhar um modo UDP:

- controle TX recebido em `:2000`;
- respostas enviadas para `:2002`;
- RTP recebido em `:5000`;
- logs estruturados para diagnostico;
- validacao de ordem e cadencia dos pacotes.
