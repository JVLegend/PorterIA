# Awesome Mac OS Apps — PR entry

Target repo: https://github.com/serhii-londar/open-source-mac-os-apps

Suggested category: **Developer Tools** (or **Utilities** if the maintainers prefer).

---

## Bullet to add

```
- [PorterIA](https://github.com/JVLegend/PorterIA) - Menu bar utility that lists listening TCP ports with the owning process and lets you kill them in one click.
```

---

## PR body — "Why include"

PorterIA fills a small but recurring developer pain point on macOS: figuring out which process is holding a TCP port (the classic `EADDRINUSE` on `:3000`, `:5173`, `:8080`, etc.) and killing it without dropping to the terminal. It lives in the menu bar, shows port + PID + process name, and frees the port in one click. It is an independent reimplementation of [Portpourri](https://github.com/inket/Portpourri) (also MIT-licensed), credited explicitly in the README, and built from scratch in Swift with a modern SwiftUI `MenuBarExtra` UI targeting macOS 14+.

The project meets the repository's typical inclusion bar: source is MIT-licensed, the build is fully reproducible (SwiftPM-based, no `.xcodeproj`), the released binary is code-signed and Apple-notarized, distribution is via a public Homebrew Cask (`brew install --cask porteria` after tapping `jvlegend/porteria`), and the app does no telemetry and requires no elevated privileges. Releases are tagged on GitHub, scripts and Cask formula are public, and the README documents install, build, and contribution paths. Happy to address any feedback before merge.
