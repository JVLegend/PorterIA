<!-- TODO before posting:
  1. Upload a screenshot of the menu bar dropdown to imgur and replace the placeholder link below.
  2. r/macapps requires the screenshot in the post body — don't skip it or the mods will remove it.
  3. Flair: "Free" / "Open Source".
-->

**Title:** `[PorterIA] Free open-source menu bar app to see who's using each port (and kill them)`

---

PorterIA is a small macOS menu bar app that lists every TCP port currently in LISTEN state, with the process that owns it, and lets you kill that process with a click. That's the whole app.

I built it because I kept hitting `EADDRINUSE :3000` and got tired of running `lsof -i :3000` in the terminal every time. It's an independent reimplementation of [Portpourri](https://github.com/inket/Portpourri) (MIT), which I'd been using for years — credit where it's due.

**What it does**
- Lists listening TCP ports with PID, process name, and port number
- One click to kill the owning process
- Lives in the menu bar, refreshes on open

**System requirements**
- macOS 14 (Sonoma) or later
- Currently Apple Silicon; universal binary (Intel + ARM) in v0.2.0, very soon

**Privacy / security**
- No telemetry, no network calls
- No elevated privileges required (uses `lsof` and `ps` on processes you own)
- Signed and notarized by Apple

**Install**
```
brew tap jvlegend/porteria
brew install --cask porteria
```

Or download the `.dmg` directly: https://github.com/JVLegend/PorterIA/releases/latest

**Source**: https://github.com/JVLegend/PorterIA

**Screenshot**: [screenshot: <upload to imgur first>]

Free. Open source MIT. No telemetry. Built in Swift.
