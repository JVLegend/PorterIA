<div align="center">

# 🌐 PorterIA

**macOS menu bar utility that shows which process, which project, and which AI tool is using each port on your machine.**

[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/JVLegend/PorterIA?color=green)](https://github.com/JVLegend/PorterIA/releases/latest)
[![Platform](https://img.shields.io/badge/macOS-14%2B-lightgrey)](https://www.apple.com/macos)
[![Swift](https://img.shields.io/badge/swift-6.3-orange.svg)](https://swift.org)
[![Universal](https://img.shields.io/badge/arch-arm64%20%2B%20x86__64-purple)]()

🇧🇷 [Versão em português](README.md)

</div>

> *No more "EADDRINUSE :3000". When a port is taken, you see who owns it and kill it in one click.*

---

## ✨ Features

| | |
|---|---|
| 🔌 **Real-time port map** | Every listening TCP port with process, PID, and bind address |
| 🤖 **AI tool detection** | Ollama, Claude Code, Codex, LM Studio, Continue.dev, Copilot, Cursor, Aider, vLLM, LiteLLM, Jupyter, and more — each with a colored badge |
| 📦 **Automatic project identification** | Reads `package.json` (`"name"` field), `Cargo.toml`, `pyproject.toml`, `go.mod`, `Gemfile`, or `.git` |
| ⚡ **One-click kill** | `SIGTERM` straight from the dropdown — no more `lsof \| grep \| kill` |
| 🚀 **Launch at login** | Built-in toggle via `SMAppService` |
| 🔄 **5-second auto-refresh** | Plus `⌘R` for manual refresh |
| 💎 **Universal binary** | Native on Apple Silicon and Intel |
| 🔒 **Full privacy** | No network, no telemetry, no elevated privileges, no disk. Just `lsof` + `kill(2)` |
| ✅ **Signed & notarized by Apple** | Distributed via Developer ID — no Gatekeeper warning |

---

## 📦 Install

### Via Homebrew Cask (recommended)

```sh
brew tap jvlegend/porteria
brew install --cask porteria
```

Upgrades:
```sh
brew upgrade --cask porteria
```

### Direct download

Download the latest `.dmg` from [Releases](https://github.com/JVLegend/PorterIA/releases/latest) and drag `PorterIA.app` to `/Applications`.

> **Requirements:** macOS 14 (Sonoma) or later. Universal binary — Apple Silicon **and** Intel.

---

## 🚀 Usage

PorterIA lives in the **menu bar** — no dock icon, no main window. After installing:

```sh
open -a PorterIA
```

Look for the network icon (🌐) in the top-right of your screen. Click to open the dropdown.

### What each row shows

```
:11434  🟠 AI  Ollama
        ollama · pid 1234 · localhost                              ×

:3000   📦  my-next-app
        node · pid 5678 · all interfaces                           ×

:5432       postgres
        pid 9012 · localhost                                       ×
```

- 🟠 **AI badge** (color varies by category): process identified as an AI tool
- 📦 **Project name**: detected from the process's working directory
- **No badge**: regular system service

### Actions

| Action | How |
|---|---|
| **Kill process** | Click the red `×` on a row → sends `SIGTERM` to the PID |
| **AI-only filter** | Toggle `All` ⇄ `AI` in the header |
| **Manual refresh** | **Refresh** button in the footer or `⌘R` |
| **Launch at login** | **Start at login** toggle in the footer |
| **Quit** | **Quit** button in the footer or `⌘Q` |

### Detected AI catalog

| Category | Tools |
|---|---|
| 🟠 **LLM server** | Ollama, LM Studio, vLLM |
| 🟣 **CLI agent** | Claude Code, Codex CLI, Aider, Goose, Open Interpreter |
| 🔵 **IDE extension** | Continue.dev, GitHub Copilot, Cursor, Tabby |
| 🟢 **Desktop app** | Claude Desktop |
| 🩷 **Notebook** | Jupyter |
| ⚪ **Remote dev** | VS Code Server / Tunnel |
| 🌊 **LLM proxy** | LiteLLM |

Don't see your tool? [Open an issue](https://github.com/JVLegend/PorterIA/issues/new) — adding a new tool is literally one line in [`AIToolFingerprinter.swift`](Sources/PorterIA/AIToolFingerprinter.swift).

---

## 🔒 Privacy

| Item | Status |
|---|---|
| Outbound network connections | ❌ **Never** |
| Telemetry / analytics | ❌ **Never** |
| Persistent disk access | ❌ **None** (no cache, no config written) |
| Elevated privileges (sudo / TCC) | ❌ **Never requested** |
| External tools invoked | ✅ Only `/usr/sbin/lsof` and `kill(2)` (both POSIX, both built into macOS) |
| Closed-source code | ❌ Everything MIT — read it in [`Sources/`](Sources/) |

---

## 🛠 Development

Clone and run locally:

```sh
git clone https://github.com/JVLegend/PorterIA
cd PorterIA

make run         # swift run (debug, foreground)
make app         # build release .app to ./build/PorterIA.app
make test        # runs 35+ XCTest
make clean
```

Full release pipeline (requires Apple Developer ID + notarytool profile):

```sh
make release     # build → sign → dmg → notarize → staple
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for PR details and code style.

### Stack

- **Swift 6** + **SwiftUI** (`MenuBarExtra`, `SMAppService`)
- **SwiftPM executable** — no `.xcodeproj`, fully reproducible from text
- System tooling: `lsof -F pcnLT`, `ps -o pid=,args=`, `kill(2)`
- **No external dependencies** (no `Package.resolved`)

### Repository layout

```
PorterIA/
├── Sources/PorterIA/
│   ├── PorterIAApp.swift          # @main, MenuBarExtra
│   ├── PortListView.swift         # dropdown UI
│   ├── PortScanner.swift          # lsof + parsing + scan loop
│   ├── AIToolFingerprinter.swift  # AI catalog + matcher
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

## 📜 License

[MIT](LICENSE).

---

<div align="center">

Made by **[João Victor Dias](https://github.com/JVLegend)** · Report a bug: [Issues](https://github.com/JVLegend/PorterIA/issues) · Changelog: [CHANGELOG.md](CHANGELOG.md)

</div>
