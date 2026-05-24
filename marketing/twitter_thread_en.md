<!-- Twitter/X thread for PorterIA launch.
     Char limits target ~270 to leave room for quote-retweets.
     Tweet 1 needs a short GIF: menu bar opens, ports listed, click to kill, port frees up.
-->

**1/8** [GIF]

Shipped PorterIA: a tiny macOS menu bar app that shows every listening TCP port + the process behind it, and kills it in one click.

Free. MIT. No telemetry. `brew install --cask porteria`.

Built in one Claude Code session. Here's how.

---

**2/8**

The problem: `Error: listen EADDRINUSE :::3000`

Every web dev knows the dance — `lsof -i :3000`, copy PID, `kill -9`, repeat. I've done it for years. Time to stop.

(Inspired by Portpourri, also MIT — credit where it's due.)

---

**3/8**

What it does, fully:

- Menu bar icon, click to open
- Lists listening TCP ports with PID + process name
- One click kills the owner

That's it. Not a dashboard. Not a platform. One job.

---

**4/8**

Technical bit 1: no Xcode project. Pure SwiftPM.

`Package.swift` + `Sources/` + `Resources/`. `swift build -c release` produces the binary. A 30-line shell script wraps it into a `.app` bundle.

No `project.pbxproj` merge conflicts. Entire project is plain text.

---

**5/8**

Technical bit 2: full notarization pipeline.

- `codesign --options runtime` with Developer ID Application cert
- `notarytool` with credentials stored in Keychain (no passwords in scripts)
- `stapler staple` on the DMG
- Homebrew Cask via personal tap with `livecheck :github_latest`

---

**6/8**

Meta: I built this end-to-end in one session with Claude Code, from `swift package init` to a notarized DMG live on Homebrew.

Not magic — a normal tool that handles the boilerplate (release scripts, lsof parsing) so I could focus on the cert debugging and architecture choices.

---

**7/8**

Try it:

```
brew tap jvlegend/porteria
brew install --cask porteria
```

Or direct DMG: github.com/JVLegend/PorterIA/releases/latest

---

**8/8**

Source, scripts, Cask all open:

https://github.com/JVLegend/PorterIA

MIT. Issues and PRs welcome. Next up: universal binary (Intel + Apple Silicon) and port → project mapping.
