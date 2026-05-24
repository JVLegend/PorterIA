🇧🇷 Versão em português. English version: [README.md](README.md)

# PorterIA

Utilitário de barra de menu para macOS — mostra qual processo/projeto é dono de cada porta e oferece ações de um clique como "Liberar porta" / "Parar servidor".

## Stack

- Swift + SwiftUI (`MenuBarExtra`, macOS 14+)
- Target executável SwiftPM (sem `.xcodeproj`)
- Usa `lsof -i -P -n -sTCP:LISTEN -F pcnLT` para descoberta de portas (sem privilégios elevados)
- Sem rede, sem telemetria
- CLI complementar opcional em Node (`port-who`) para uso headless / scripting — fase 2

## Build & execução local

```sh
make run         # swift run (debug, em primeiro plano)
make app         # build release do .app em ./build/PorterIA.app
open build/PorterIA.app
make clean
```

O app aparece na barra de menu (sem ícone na dock — `LSUIElement` está ativo). Clique no ícone de rede para ver as portas em escuta; o refresh é automático a cada 5s.

## Instalação (planejado)

```sh
brew install --cask porteria
```

> Token do Homebrew Cask: `porteria` (minúsculo, sem hífen). Nome de exibição: `PorterIA`.

## Plano de distribuição

| Canal | Status | Observações |
|---|---|---|
| **Homebrew Cask** | principal | Token `porteria` confirmado disponível (404 na API do brew em 2026-05-23). |
| **GitHub Releases (.dmg notarizado)** | base | Necessário para o Gatekeeper. O Cask aponta para o `.dmg` do release. |
| **Mac App Store** | pular | O sandbox restringe o `lsof`. Mesmo motivo pelo qual o Portpourri fica fora da MAS. |
| **npm (helper CLI)** | fase 2 | Apenas se a CLI `port-who` sair do papel. |
| **pip** | n/a | Público errado, runtime errado para um app de barra de menu. |

## Layout

```
PorterIA/
├── app/         # App Swift de barra de menu (projeto Xcode)
├── cli/         # Helper CLI opcional em Node (npm) — fase 2
├── Casks/       # porteria.rb (vive no tap do homebrew depois de publicado)
└── docs/
```

## Licença

MIT (mesma da inspiração upstream).
