# PorterIA

🇺🇸 [English version](README_en.md)

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

## Instalação

Via Homebrew Cask:

```sh
brew tap jvlegend/porteria
brew install --cask porteria
```

Ou baixe o `.dmg` mais recente (assinado e notarizado pela Apple) na [página de Releases](https://github.com/JVLegend/PorterIA/releases/latest) e arraste o `PorterIA.app` para `/Applications`.

Requer macOS 14 (Sonoma) ou superior. Binário universal — roda nativamente em Macs Apple Silicon e Intel.

## Como usar

O PorterIA vive na barra de menu — **não há ícone na dock e não há janela principal**. Depois de instalar, abra uma vez a partir de `/Applications` (ou via `open -a PorterIA`) e procure pelo ícone de rede (🌐 na parte superior direita da tela).

Clique no ícone para abrir o menu suspenso. Você vai ver:

- Todas as portas TCP em escuta na sua máquina, ordenadas por número
- O **nome do processo** e o PID que detêm cada porta
- O **nome do projeto**, quando detectável (lê o campo `"name"` de `package.json`, ou o nome do diretório que tem o ancestral mais próximo com `Cargo.toml` / `pyproject.toml` / `go.mod` / `Gemfile` / `.git`)
- O **endereço de bind**, traduzido: `localhost`, `todas as interfaces`, ou o host literal

Ações:

- **Encerrar um processo** — clique no botão vermelho `×` na linha. Envia `SIGTERM` para o PID dono. A lista atualiza imediatamente.
- **Atualizar manualmente** — clique em *Refresh* no rodapé ou pressione `⌘R`. A lista também atualiza automaticamente a cada 5 segundos enquanto aberta.
- **Sair do PorterIA** — clique em *Quit* no rodapé ou pressione `⌘Q`.
- **Abrir no login** — atualmente manual: arraste o `PorterIA.app` para *Ajustes do Sistema → Geral → Itens de Início de Sessão → Abrir no Login*. (Toggle nativo chegando na v0.4.0.)

Privacidade: o PorterIA **não faz nenhuma chamada de rede**, **não pede privilégios elevados**, não armazena nada em disco e não contém telemetria. Os únicos comandos externos invocados são `lsof` e `kill(2)`, ambos ferramentas padrão do macOS.

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
