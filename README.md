# PorterIA

🇧🇷 [Versão em português](README_pt-BR.md)

macOS menu bar utility — shows which process/project owns each port and offers one-click "Free port" / "Stop server" actions.

Inspired by [Portpourri](https://www.portpourri.com/) (MIT). Independent reimplementation.

## Status

**Phase 1 MVP working locally** (2026-05-23). Lists listening TCP ports in a menu bar dropdown with kill buttons. Not yet signed, notarized, or shipped.

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

## Homebrew Cask requirements (so the cask is acceptable)

To get into `homebrew/cask` (or even just install from a tap), the build must satisfy:

1. **Stable versioned release** on GitHub Releases (e.g. `v0.1.0`).
2. **Notarized & stapled `.dmg`** (Apple Developer ID, `xcrun notarytool submit ... --wait`, `xcrun stapler staple`).
3. **Stable download URL** with version interpolation (e.g. `https://github.com/<user>/PorterIA/releases/download/v#{version}/PorterIA-#{version}.dmg`).
4. **SHA-256 checksum** of the `.dmg`.
5. **`livecheck` block** so brew can auto-detect new versions.
6. **`uninstall` + `zap` stanzas** declaring app paths and preference files to remove cleanly.
7. **App signed with hardened runtime** and a real bundle identifier (e.g. `com.jvdias.PorterIA`).

Minimum cask skeleton (placeholder — fill after first release):

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

Initially this lives in a personal tap (`brew tap jvlegend/porteria && brew install --cask porteria`); promotion to `homebrew/cask` only after the project is stable, has releases, and meets [acceptable casks criteria](https://docs.brew.sh/Acceptable-Casks).

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
