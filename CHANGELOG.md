# Changelog

All notable changes to PorterIA are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-05-23

### Added
- **"AI tools active (no port)" section** below the main port list. Shows AI applications that are running but don't listen on a TCP port (Claude Desktop, Codex Desktop talking over stdio, etc.). One row per detected tool with kill button.
- `AIProcess` model + `AIProcessScanner` that walks `ps -A -o pid=,args=` and fingerprints every running process. Dedupes by tool display name (lowest PID wins) so Electron helpers don't spam the UI.
- `PortStore.aiProcessesWithoutPort` published property, excludes any PID already shown in the port list.

### Changed
- **AI catalog updated for real cmdlines.** Captured the actual `ps` output from a live Claude Desktop + Codex Desktop install and adjusted regexes:
  - `Claude Desktop` now anchored to `^/Applications/Claude.app/Contents/MacOS/Claude` so Electron helpers (renderer, GPU, network) don't match.
  - `Codex Desktop` (new) matches `/Applications/Codex.app/Contents/{MacOS/Codex,Resources/codex,Resources/node_repl}`.
  - `Claude Code` now also catches the disclaimer wrapper that Claude Desktop spawns to run an embedded Claude Code, and the inner `Application Support/Claude/claude-code/` binary.
  - Catalog order: Desktop apps matched **before** CLI patterns so a Codex Desktop subprocess gets tagged as Desktop, not CLI.
- 9 new tests in `AIProcessScannerTests` covering Electron-helper rejection, dedupe, and Desktop-vs-CLI disambiguation. Suite at 44 total.

## [0.4.0] - 2026-05-23

### Added
- **AI tools detection** — rows for processes recognized as AI dev tools now show a colored `AI` badge and friendlier name. Catalog covers: Ollama, LM Studio, vLLM, Claude Code, Codex CLI, Aider, Goose, Open Interpreter, Continue.dev, GitHub Copilot, Cursor, Tabby, LiteLLM, Claude Desktop, Jupyter, VS Code Server. Implemented as regex match against full `ps -p PID -o args=` output in `AIToolFingerprinter`.
- **Filter toggle** in the header: switch between `All` and `AI` views. `AI` shows only ports owned by recognized AI tooling.
- **AI count badge** in the header when at least one AI tool is detected.
- **Launch at Login toggle** in the footer (powered by `SMAppService.mainApp`). One-click enable / disable, persists across reboots, no system settings round-trip.
- 20 new `AIToolFingerprinterTests` covering all catalog entries + ps output parsing edge cases. Test suite now at 35 total.

### Changed
- `PortEntry.primaryLabel` now prefers the AI tool display name over the project name and raw command.
- Per-category badge colors: LLM servers = orange, agents = purple, IDE extensions = blue, proxies = teal, desktop apps = green, notebooks = pink, remote dev = gray.

### Fixed
- **Critical: zero ports shown after install.** `runProcess` piped stderr without ever reading it, and `lsof` writes warnings to stderr (denied access to system processes). The 64KB stderr buffer filled, `lsof` blocked on `write()`, `waitUntilExit()` deadlocked, `scan()` never returned, and the dropdown showed nothing. Fix: route stderr to `FileHandle.nullDevice` and read stdout before waiting on exit. Same fix applied to `AIToolFingerprinter.cmdlines()`.
- README reorganized: Install before Build, badges, AI catalog table, privacy table, GitHub Topics shields. Polished for technical audience. Same treatment in `README_en.md`.

## [0.3.0] - 2026-05-23

### Added
- **Project mapping**: each row now shows the owning project (from `package.json` "name" or directory basename) when detectable. Walks up from each process's cwd looking for `package.json`, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, or `.git`.
- `ProjectDetector` enum with up-to-10-levels ancestor walk.
- `cwd` lookup via batched `lsof -p PID1,PID2,... -d cwd`.
- XCTest suite (`PorterIATests`) covering port extraction, lsof parsing, dedupe, bind label humanization, primary/secondary label rendering, and project detection (15 tests).
- `Tests/PorterIATests/Fixtures/lsof_listen_sample.txt` fixture from real lsof output.

### Fixed
- `PortEntry.bindLabel` now correctly humanizes IPv6 `[::1]:8080` as `localhost` (previously rendered `[:1]` because `split(separator: ":")` was eating the `::`).

### Changed
- `PortEntry` gained `projectPath` and `projectName` fields.
- `PortListView` displays project name (when present) as the primary label, with the command moved into the secondary line.

## [0.2.0] - 2026-05-23

### Added
- Universal binary (`arm64` + `x86_64`) — now runs natively on both Apple Silicon and Intel Macs.
- Custom app icon (`Resources/AppIcon.icns`) bundled into `PorterIA.app`.
- Reproducible icon generator script at `scripts/gen-icon.py`.
- Portuguese (Brazilian) `README_pt-BR.md` mirror.
- `CHANGELOG.md` and `CONTRIBUTING.md`.

### Changed
- `scripts/build-app.sh` now produces a universal binary via two `swift build --triple` invocations + `lipo -create`.
- `Info.plist` bumped to version 0.2.0 with `CFBundleIconFile=AppIcon`.

## [0.1.0] - 2026-05-23

### Added
- Initial public release as a macOS menu bar utility.
- Listening TCP port discovery via `lsof -F pcnLT -i -P -n -sTCP:LISTEN` (no elevated privileges required).
- SwiftUI `MenuBarExtra` dropdown listing each port with process name, PID, and bind address.
- One-click kill button per row sending `SIGTERM` (`kill -TERM`) to the owning process.
- Automatic refresh of the port list every 5 seconds while the menu is open.
- Humanized bind label rendering (`*`, `127.0.0.1`, `::1`, IPv6 addresses) for readability.
- Hover states on rows and the kill button for clearer affordances.
- Signed and notarized `.dmg` distribution via the `make release` pipeline.
- Homebrew Cask `porteria` available through the `jvlegend/porteria` tap.

[Unreleased]: https://github.com/JVLegend/PorterIA/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/JVLegend/PorterIA/releases/tag/v0.5.0
[0.4.0]: https://github.com/JVLegend/PorterIA/releases/tag/v0.4.0
[0.3.0]: https://github.com/JVLegend/PorterIA/releases/tag/v0.3.0
[0.2.0]: https://github.com/JVLegend/PorterIA/releases/tag/v0.2.0
[0.1.0]: https://github.com/JVLegend/PorterIA/releases/tag/v0.1.0
