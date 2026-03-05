.PHONY: build app run-app dmg dmg-arm64 dmg-x86_64 dmg-universal dmg-all

build:
	swift build

app:
	bash scripts/build_app.sh

run-app: app
	open dist/wewi.app

dmg: dmg-universal

dmg-arm64:
	bash scripts/build_dmg.sh arm64

dmg-x86_64:
	bash scripts/build_dmg.sh x86_64

dmg-universal:
	bash scripts/build_dmg.sh universal

dmg-all: dmg-arm64 dmg-x86_64 dmg-universal
