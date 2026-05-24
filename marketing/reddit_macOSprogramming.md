<!-- Target subreddit: r/macOSprogramming
     Flair suggestion: "Showcase" or "Discussion"
-->

**Title:** `Shipped a notarized menu bar app + Homebrew Cask using only SwiftPM (no Xcode project)`

---

I just released [PorterIA](https://github.com/JVLegend/PorterIA), a small menu bar utility that lists listening TCP ports and the processes that own them. The app itself is tiny — the more interesting part for this subreddit is the build/ship setup, which is 100% SwiftPM, no `.xcodeproj`. Sharing what worked in case anyone else wants to skip Xcode for a small app.

**Why SwiftPM over a `.xcodeproj`**
- Entire project is plain text. No `project.pbxproj` merge conflicts, no UUID churn.
- `swift build -c release` is the only build command. Trivial to wire into CI.
- Easier to reason about: `Package.swift`, `Sources/`, `Resources/`, done.
- Tradeoff: you have to assemble the `.app` bundle yourself. It's about 30 lines of shell.

**Bundling the `.app` from `swift build` output**
A small `scripts/bundle.sh` copies the binary into `PorterIA.app/Contents/MacOS/`, drops an `Info.plist` with `LSUIElement=true` (menu bar only, no Dock icon), and copies the `.icns` into `Contents/Resources/`. SwiftPM resources go through the generated `Bundle.module`, which works fine inside a hand-bundled `.app`.

**Code signing**
```sh
codesign --force --options runtime \
  --entitlements PorterIA.entitlements \
  --sign "Developer ID Application: <NAME> (<TEAMID>)" \
  PorterIA.app
```
Two gotchas worth flagging: you want **Developer ID Application** (not Apple Distribution — that one is for the App Store and notarization rejects it), and `--options runtime` is mandatory or notarization fails with a generic "hardened runtime not enabled" error.

**Notarization with `notarytool` + keychain profile**
Avoid putting an app-specific password in scripts. One-time setup:
```sh
xcrun notarytool store-credentials "PorterIA-Notary" \
  --apple-id "you@example.com" \
  --team-id "<TEAMID>" \
  --password "<app-specific-password>"
```
Then in the release script: `xcrun notarytool submit PorterIA.dmg --keychain-profile PorterIA-Notary --wait` and `xcrun stapler staple PorterIA.dmg`.

**Homebrew Cask via a personal tap**
Tap repo: `homebrew-porteria`. The Cask uses `livecheck` with `strategy :github_latest`, so `brew bump-cask-pr` (or just `brew upgrade`) follows GitHub releases automatically — no manual version pin updates per release.

**Universal binary**
Planned for v0.2.0: build twice with `--arch arm64` and `--arch x86_64`, then `lipo -create -output PorterIA PorterIA-arm64 PorterIA-x86_64`. Notarization then happens on the merged binary inside the bundle.

Full Makefile + release scripts are in the repo: https://github.com/JVLegend/PorterIA

Happy to answer questions, and PRs welcome — especially if you've found a cleaner way to handle the `.app` bundling step from SwiftPM.
