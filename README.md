<div align="center">

# 🌐 PorterIA

**Utilitário de barra de menu para macOS que mostra qual processo, qual projeto e qual ferramenta de IA está usando cada porta da sua máquina.**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/JVLegend/PorterIA?color=green)](https://github.com/JVLegend/PorterIA/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-14%2B-lightgrey)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/swift-6.3-orange.svg)](https://swift.org)
[![Universal](https://img.shields.io/badge/arch-arm64%20%2B%20x86__64-purple)]()

🇺🇸 [English version](README_en.md)

</div>

> *Acabou o "EADDRINUSE :3000". Sempre que uma porta está ocupada, você vê quem é dono e mata com um clique.*

---

## ✨ Recursos

| | |
|---|---|
| 🔌 **Mapa de portas em tempo real** | Toda porta TCP em escuta, com processo, PID e endereço de bind |
| 🤖 **Detecção de ferramentas de IA** | Ollama, Claude Code, Codex, LM Studio, Continue.dev, Copilot, Cursor, Aider, vLLM, LiteLLM, Jupyter e mais — todas com badge colorido |
| 📦 **Identificação automática de projeto** | Lê `package.json` (campo `"name"`), `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, ou `.git` |
| ⚡ **Encerrar processo com um clique** | `SIGTERM` direto pelo dropdown — sem `lsof \| grep \| kill` |
| 🚀 **Iniciar no login** | Toggle integrado via `SMAppService` |
| 🔄 **Auto-refresh a cada 5 segundos** | Mais `⌘R` pra atualização manual |
| 💎 **Universal binary** | Roda nativo em Apple Silicon e Intel |
| 📌 **Pin / watchlist** | Marque portas favoritas (3000, 5432) — ficam sempre no topo e indicam quando estão livres |
| 🗂 **Group by project** | Toggle no header para agrupar portas por projeto |
| 🕐 **Recently freed** | Mostra portas que tinham processo no último 5min mas estão livres agora |
| 🔍 **Search / filter** | Busca por porta, processo, projeto ou nome de ferramenta de IA |
| 📋 **Copy URL** | 1 clique copia `http://localhost:PORT` |
| 🤖 **Servidor MCP embutido** | Claude Code / Codex / qualquer agente MCP podem perguntar "quais portas estão em uso?" — toggle no rodapé |
| 🔒 **Privacidade total** | Sem rede outbound, sem telemetria, sem privilégio elevado, sem disco. Só `lsof` + `kill(2)` + servidor MCP local (127.0.0.1, nunca LAN) |
| ✅ **Assinado e notarizado pela Apple** | Distribuído via Developer ID, sem bloqueio do Gatekeeper |

---

## 📦 Instalação

### Via Homebrew Cask (recomendado)

```sh
brew tap jvlegend/porteria
brew install --cask porteria
```

Atualizações futuras:
```sh
brew upgrade --cask porteria
```

### Download direto

Baixe o `.dmg` mais recente em [Releases](https://github.com/JVLegend/PorterIA/releases/latest) e arraste `PorterIA.app` para `/Applications`.

> **Requisitos:** macOS 14 (Sonoma) ou superior. Universal binary — Apple Silicon **e** Intel.

---

## 🚀 Como usar

O PorterIA vive na **barra de menu** — não há ícone na dock e não há janela principal. Depois de instalar:

```sh
open -a PorterIA
```

Procure pelo ícone de rede (🌐) no canto superior direito da tela. Clique pra abrir o dropdown.

### O que cada linha mostra

```
:11434  🟠 AI  Ollama
        ollama · pid 1234 · localhost                              ×

:3000   📦  my-next-app
        node · pid 5678 · all interfaces                           ×

:5432       postgres
        pid 9012 · localhost                                       ×
```

- 🟠 **Badge AI** (cor varia por categoria): processo identificado como ferramenta de IA
- 📦 **Nome do projeto**: detectado a partir do diretório de trabalho do processo
- **Sem badge**: serviço comum do sistema

### Ações

| Ação | Como |
|---|---|
| **Encerrar processo** | Clique no `×` vermelho na linha → envia `SIGTERM` ao PID |
| **Filtrar só IA** | Toggle `All` ⇄ `AI` no header |
| **Atualizar manualmente** | Botão **Refresh** no rodapé ou `⌘R` |
| **Iniciar no login** | Toggle **Start at login** no rodapé |
| **Sair** | Botão **Quit** no rodapé ou `⌘Q` |

### Catálogo de IA detectada

| Categoria | Ferramentas |
|---|---|
| 🟠 **Servidor LLM** | Ollama, LM Studio, vLLM |
| 🟣 **Agente CLI** | Claude Code, Codex CLI, Aider, Goose, Open Interpreter |
| 🔵 **Extensão IDE** | Continue.dev, GitHub Copilot, Cursor, Tabby |
| 🟢 **App desktop** | Claude Desktop |
| 🩷 **Notebook** | Jupyter |
| ⚪ **Dev remoto** | VS Code Server / Tunnel |
| 🌊 **Proxy LLM** | LiteLLM |

Não viu sua ferramenta? [Abre uma issue](https://github.com/JVLegend/PorterIA/issues/new) — adicionar nova ferramenta é literalmente uma linha em [`AIToolFingerprinter.swift`](Sources/PorterIA/AIToolFingerprinter.swift).

---

## 🤖 Servidor MCP (Claude Code / Codex)

Desde a v0.9, o PorterIA expõe sua inteligência de portas como um **servidor MCP** local. Qualquer agente compatível com Model Context Protocol (Claude Code, Codex, etc.) pode perguntar coisas como *"quais portas eu estou usando?"*, *"quem está na :3000?"*, *"mata o processo da :5432"*.

### Como ligar

1. Clique no toggle **MCP** no rodapé da janela (bolinha verde = rodando)
2. Adicione ao `~/Library/Application Support/Claude/claude_desktop_config.json` (Claude Desktop) ou ao config do Codex:

```json
{
  "mcpServers": {
    "porteria": {
      "type": "http",
      "url": "http://localhost:9876/mcp"
    }
  }
}
```

3. Reinicie o Claude Desktop / Codex
4. Pergunte: *"Use o porteria pra me listar as portas em uso. Tem alguma ferramenta de IA rodando?"*

### Tools expostas

| Tool | O que faz |
|---|---|
| `list_ports` | Todas as portas TCP em escuta, com processo, projeto, AI tool, CPU%, bind |
| `find_port` | Detalhe completo de uma porta específica |
| `list_ai_tools` | Ferramentas de IA ativas (com porta E sem porta) |
| `list_recently_freed` | Portas que tinham processo no último 5min e estão livres agora |
| `kill_port` | SIGTERM no processo dono de uma porta |

O servidor escuta apenas em `127.0.0.1:9876` — **nunca exposto pra rede local**. Sem auth (assume confiança no localhost).

## 🔒 Privacidade

| Item | Status |
|---|---|
| Conexões de rede de saída | ❌ **Nunca** |
| Servidor MCP (quando ligado) | ✅ Só `127.0.0.1:9876` — nunca exposto pra LAN |
| Telemetria / analytics | ❌ **Nunca** |
| Acesso a disco persistente | ❌ **Nada** (sem cache, sem config gravada) |
| Privilégios elevados (sudo / TCC) | ❌ **Não pede** |
| Ferramentas externas chamadas | ✅ Apenas `/usr/sbin/lsof` e `kill(2)` (POSIX, ambos padrão do macOS) |
| Código fechado | ❌ Tudo MIT, leia em [`Sources/`](Sources/) |

---

## 🛠 Desenvolvimento

Clone e rode local:

```sh
git clone https://github.com/JVLegend/PorterIA
cd PorterIA

make run         # swift run (debug, foreground)
make app         # build release .app em ./build/PorterIA.app
make test        # roda os 35+ XCTest
make clean
```

Pipeline completo de release (precisa de Apple Developer ID + notarytool profile):

```sh
make release     # build → sign → dmg → notarize → staple
```

Veja [`CONTRIBUTING.md`](CONTRIBUTING.md) pra detalhes de PR e estilo de código.

### Stack

- **Swift 6** + **SwiftUI** (`MenuBarExtra`, `SMAppService`)
- **SwiftPM executable** — sem `.xcodeproj`, tudo reproduzível em texto
- Macros do sistema: `lsof -F pcnLT`, `ps -o pid=,args=`, `kill(2)`
- **Sem dependências externas** (no `Package.resolved`)

### Layout do repositório

```
PorterIA/
├── Sources/PorterIA/
│   ├── PorterIAApp.swift          # @main, MenuBarExtra
│   ├── PortListView.swift         # UI do dropdown
│   ├── PortScanner.swift          # lsof + parsing + scan loop
│   ├── AIToolFingerprinter.swift  # catálogo de IA + matcher
│   ├── LaunchAtLogin.swift        # SMAppService wrapper
│   └── Models.swift               # PortEntry, AITool
├── Tests/PorterIATests/           # 35+ XCTest
├── Resources/
│   ├── Info.plist
│   ├── PorterIA.entitlements
│   └── AppIcon.icns
└── scripts/                       # build, sign, dmg, notarize, gen-icon
```

---

## 📜 Licença

[MIT](LICENSE).

---

<div align="center">

Feito por **[João Victor Dias](https://github.com/JVLegend)** · Reportar bug: [Issues](https://github.com/JVLegend/PorterIA/issues) · Changelog: [CHANGELOG.md](CHANGELOG.md)

</div>
