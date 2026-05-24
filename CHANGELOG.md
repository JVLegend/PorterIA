# Changelog

All notable changes to PorterIA are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/JVLegend/PorterIA/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/JVLegend/PorterIA/releases/tag/v0.3.0
[0.2.0]: https://github.com/JVLegend/PorterIA/releases/tag/v0.2.0
[0.1.0]: https://github.com/JVLegend/PorterIA/releases/tag/v0.1.0
