🇧🇷 Versão em português. English version: [README.md](README.md)

# PorterIA

Utilitário de barra de menu para macOS — mostra qual processo/projeto é dono de cada porta e oferece ações de um clique como "Liberar porta" / "Parar servidor".

Inspirado no [Portpourri](https://www.portpourri.com/) (MIT). Reimplementação independente.

## Status

**MVP da Fase 1 funcionando localmente** (2026-05-23). Lista portas TCP em escuta num menu suspenso da barra de menu, com botões de encerrar processo. Ainda não assinado, notarizado ou publicado.

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

## Requisitos do Homebrew Cask (para o cask ser aceito)

Para entrar no `homebrew/cask` (ou mesmo só instalar via um tap), o build precisa atender:

1. **Release versionado estável** no GitHub Releases (ex.: `v0.1.0`).
2. **`.dmg` notarizado e com staple** (Apple Developer ID, `xcrun notarytool submit ... --wait`, `xcrun stapler staple`).
3. **URL de download estável** com interpolação de versão (ex.: `https://github.com/<user>/PorterIA/releases/download/v#{version}/PorterIA-#{version}.dmg`).
4. **Checksum SHA-256** do `.dmg`.
5. **Bloco `livecheck`** para que o brew detecte novas versões automaticamente.
6. **Stanzas `uninstall` + `zap`** declarando caminhos do app e arquivos de preferência para remoção limpa.
7. **App assinado com hardened runtime** e um bundle identifier real (ex.: `com.jvdias.PorterIA`).

Esqueleto mínimo do cask (placeholder — preencher após o primeiro release):

```ruby
cask "porteria" do
  version "0.1.0"
  sha256 "REPLACE_AFTER_BUILD"

  url "https://github.com/JVLegend/PorterIA/releases/download/v#{version}/PorterIA-#{version}.dmg"
  name "PorterIA"
  desc "Menu bar utility that maps ports to processes and projects"
  homepage "https://github.com/JVLegend/PorterIA"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "PorterIA.app"

  zap trash: [
    "~/Library/Preferences/com.jvdias.PorterIA.plist",
    "~/Library/Application Support/PorterIA",
  ]
end
```

Inicialmente isso vive num tap pessoal (`brew tap jvlegend/porteria && brew install --cask porteria`); a promoção para o `homebrew/cask` oficial só vem depois que o projeto estiver estável, com releases regulares, e atender aos [critérios de casks aceitáveis](https://docs.brew.sh/Acceptable-Casks).

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
