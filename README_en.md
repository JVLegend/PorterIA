# PorterIA

🇧🇷 [Versão em português](README.md)

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

## Install

Via Homebrew Cask:

```sh
brew tap jvlegend/porteria
brew install --cask porteria
```

Or download the latest signed and notarized `.dmg` from the [Releases page](https://github.com/JVLegend/PorterIA/releases/latest) and drag `PorterIA.app` into `/Applications`.

Requires macOS 14 (Sonoma) or later. Universal binary — runs natively on both Apple Silicon and Intel Macs.

## Usage

PorterIA lives in the menu bar — there is **no dock icon and no main window**. After installing, launch it once from `/Applications` (or via `open -a PorterIA`) and look for the network icon (🌐 in the top-right area of your screen).

Click the icon to open the dropdown. You'll see:

- Every listening TCP port on your machine, sorted by port number
- The owning **process name** and PID
- The **project name** when detectable (from `package.json` "name" field, or the directory name of the nearest `Cargo.toml` / `pyproject.toml` / `go.mod` / `Gemfile` / `.git` ancestor)
- The **bind address**, humanized: `localhost`, `all interfaces`, or the literal host

Actions:

- **Kill a process** — click the red `×` button on a row. Sends `SIGTERM` to the owning PID. The list refreshes immediately.
- **Refresh manually** — click *Refresh* in the footer or press `⌘R`. The list also auto-refreshes every 5 seconds while open.
- **Quit PorterIA** — click *Quit* in the footer or press `⌘Q`.
- **Launch at login** — currently manual: drag `PorterIA.app` into *System Settings → General → Login Items → Open at Login*. (Built-in toggle coming in v0.4.0.)

Privacy: PorterIA makes **no network calls**, requires **no elevated privileges**, stores nothing on disk, and contains no telemetry. The only external commands invoked are `lsof` and `kill(2)`, both standard macOS tools.

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
