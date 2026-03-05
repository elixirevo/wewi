.PHONY: build app run-app dmg dmg-arm64 dmg-x86_64 dmg-all

build:
	swift build

app:
	bash scripts/build_app.sh

run-app: app
	open dist/wewi.app

dmg: dmg-arm64

dmg-arm64:
	bash scripts/build_dmg.sh arm64

dmg-x86_64:
	bash scripts/build_dmg.sh x86_64

dmg-all: dmg-arm64 dmg-x86_64
