# Contributing to PorterIA

Thanks for your interest in PorterIA. Contributions are welcome — bug reports, fixes, and small focused features all help.

PorterIA is intentionally minimal: a menu bar utility that maps listening TCP ports to processes and lets you kill them. Please keep that scope in mind. Feature additions should be small and discussed in an issue first.

## Development setup

PorterIA is a SwiftPM executable. There is no `.xcodeproj`.

```sh
git clone https://github.com/JVLegend/PorterIA.git
cd PorterIA
swift build              # build debug
swift run                # run in foreground (menu bar app appears, logs to stdout)
make app                 # build release .app at ./build/PorterIA.app
```

Requirements:
- macOS 14 (Sonoma) or later
- Swift 5.9+ (Xcode 15+ recommended)

## Project structure

```
PorterIA/
├── Sources/PorterIA/    # Swift sources (MenuBarExtra app, port scanning, kill logic)
├── Resources/           # Assets (icon, Info.plist values)
├── scripts/             # Build, sign, notarize, dmg helpers
├── Package.swift        # SwiftPM manifest
└── Makefile             # Convenience targets (run, app, release, clean)
```

## How to add a feature

1. **Open an issue first** for anything non-trivial. A two-line description of the problem and the proposed approach is enough.
2. Wait for a quick acknowledgement before investing significant effort — this avoids wasted work on changes that fall outside the project's scope.
3. Small fixes (typos, obvious bugs, doc improvements) can go straight to a PR without an issue.

## Code style

- **Swift 5.9**, standard SwiftUI conventions.
- **No force-unwraps** (`!`) in production code. Use `guard let` / `if let` or provide a meaningful default.
- **Prefer `@MainActor`** for view models and any state driving UI updates.
- Use Swift's standard formatting (no project-specific formatter is enforced yet).
- Keep functions short and side-effect-free where possible.
- Match the existing style of the file you're editing.

## Testing

- Tests live under `Tests/PorterIATests/` and use `XCTest`.
- Place fixture data (sample `lsof` output, etc.) alongside the tests that consume it.
- Run the full suite with:

```sh
swift test
```

- New behavior should ship with at least one test exercising the happy path. Bug fixes should include a regression test.

## Pull requests

1. Fork the repo and create a feature branch from `main`:
   ```sh
   git checkout -b feature/short-description
   ```
2. Make focused commits with clear messages.
3. Ensure `swift build` and `swift test` pass locally.
4. Open a PR against `main` and describe:
   - What the change does
   - Why it's needed (link to issue if applicable)
   - Any user-visible behavior change
5. Be patient — reviews are best-effort.

## Release process

Releases are cut by the maintainer only. For reference, the pipeline is:

```sh
make app        # build the .app
make release    # full sign + notarize + dmg pipeline, updates Homebrew Cask
```

Contributors do not need to run these targets.

## Code of conduct

Be respectful. Assume good intent. Discussions stay on the technical merits.

## License

By contributing, you agree that your contributions will be licensed under the [MIT License](LICENSE).
