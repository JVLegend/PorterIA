.PHONY: build run app sign dmg notarize release setup-signing clean test

setup-signing:
	./scripts/setup-signing.sh

build:
	swift build

run:
	swift run

app:
	./scripts/build-app.sh release

sign: app
	./scripts/sign.sh

dmg: sign
	./scripts/dmg.sh

notarize: dmg
	./scripts/notarize.sh

# Full release pipeline: build .app, sign, package .dmg, notarize, staple.
release: notarize
	@echo ""
	@echo "===================================================="
	@echo "  Release ready in ./build/"
	@echo "  Upload PorterIA-<version>.dmg to GitHub Releases."
	@echo "===================================================="

clean:
	rm -rf .build build

test:
	swift test
