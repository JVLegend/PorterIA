# PorterIA

🇧🇷 [Versão em português](README_pt-BR.md)

macOS menu bar utility — shows which process/project owns each port and offers one-click "Free port" / "Stop server" actions.

## Stack

- Swift + SwiftUI (`MenuBarExtra`, macOS 14+)
- SwiftPM executable target (no `.xcodeproj`)
- Uses `lsof -i -P -n -sTCP:LISTEN -F pcnLT` for port discovery (no elevated privileges)
- No network, no telemetry
- Optional companion CLI in Node (`port-who`) for headless / scripting use — phase 2

## Build & run locally

```sh
make run         # swift run (debug, foreground)
make app         # build release .app at ./build/PorterIA.app
open build/PorterIA.app
make clean
```

App appears in the menu bar (no dock icon — `LSUIElement` is set). Click the network icon to see listening ports; refresh is automatic every 5s.

## Install (planned)

```sh
brew install --cask porteria
```

> Homebrew Cask token: `porteria` (lowercase, no hyphen). Display name: `PorterIA`.

## Distribution plan

| Channel | Status | Notes |
|---|---|---|
| **Homebrew Cask** | primary | Token `porteria` confirmed available (404 on brew API as of 2026-05-23). |
| **GitHub Releases (.dmg notarized)** | baseline | Required for Gatekeeper. Cask points to the release `.dmg`. |
| **Mac App Store** | skip | Sandbox restricts `lsof`. Same reason Portpourri stays off MAS. |
| **npm (CLI helper)** | phase 2 | Only if `port-who` CLI happens. |
| **pip** | n/a | Wrong audience, wrong runtime for menu bar. |

## Layout

```
PorterIA/
├── app/         # Swift menu bar app (Xcode project)
├── cli/         # Optional Node CLI helper (npm) — phase 2
├── Casks/       # porteria.rb (lives in homebrew tap once published)
└── docs/
```

## License

MIT (matching upstream inspiration).
