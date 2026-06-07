# wewi 🌐

![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)
![Swift](https://img.shields.io/badge/Swift-6-orange.svg)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

<img src="./wewi_icons/wewi-iOS-Default-1024x1024@1x.png" alt="wewi Icon" width="160" />

**wewi** is a native macOS app that pins live web pages to your desktop as widgets.

Use it for dashboards, charts, docs, notes, and any URL you want to keep visible while working.

## ✨ Features

- Pin any URL as a desktop widget (`WKWebView`)
- Multiple widgets at once
- Widgets visible across Spaces
- Move and resize widgets directly on desktop
- Resize handle with concentric-circle indicator (hover to show, auto-hide delay)
- Widget body background fill behind web content (prevents transparent gaps on overscroll)
- System appearance sync signal to widget pages (`data-wewi-color-scheme` + change event)
- Per-widget settings:
  - Name, URL, position, size
  - Opacity
  - Auto-refresh interval
  - Enable/disable
  - Screen Lock mode (blocks web interaction)
- Widget top bar actions:
  - Save scroll position
  - Reload
  - Screen Lock toggle (`ON` = blocked, `OFF` = interactive)
  - Disable widget
- Menu bar controls:
  - Open Settings
  - Check for Updates
  - Enable/disable, reload, delete widgets
- Auto-save widget settings (`UserDefaults` JSON)
- Restore each widget browser's saved scroll position after app relaunch
- Launch at login toggle in Settings
- Auto-scroll to newly added widget in Widget List

## 🧭 Usage

1. Launch `wewi.app`
2. Open **Settings** from menu bar
3. In **Create New Widget**:
   - Enter Name + URL
   - Select size preset
   - Click **Add Widget**
4. Manage all widgets in **Widget List** (changes apply immediately)

## 🚀 Build

### Prerequisites

- macOS 13+
- Xcode Command Line Tools (`xcode-select --install`)

### Run (debug)

```bash
swift run
```

### Build app bundle

```bash
make app
```

Built app path:

```text
dist/wewi.app
```

### Build DMG for distribution

```bash
# Optional: set Developer ID identity for trusted distribution
# export SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#
# arm64
make dmg-arm64

# x86_64
make dmg-x86_64

# universal (arm64 + x86_64)
make dmg-universal

# both
make dmg-all
```

Generated DMG filenames:

```text
dist/wewi-1.0.2-arm64.dmg
dist/wewi-1.0.2-x86_64.dmg
dist/wewi-1.0.2-universal.dmg
```

Note:
- Default build uses ad-hoc signing (`SIGN_IDENTITY=-`) for local testing.
- For public distribution, use a valid `Developer ID Application` certificate and notarize the DMG/app. Without this, Gatekeeper may show "app is damaged" or block launch on other Macs.
- With ad-hoc distribution, users may need to remove quarantine manually:
  - `xattr -dr com.apple.quarantine /Applications/wewi.app`
  - `open /Applications/wewi.app`

### Sparkle Updates

wewi uses Sparkle 2 for automatic update checks.

The appcast URL embedded in the app bundle is:

```text
https://github.com/elixirevo/wewi/releases/latest/download/appcast.xml
```

Generate the Sparkle EdDSA key pair once:

```bash
make sparkle-keys
```

This stores the private key in your macOS Keychain and writes the public key to:

```text
sparkle-public-key.txt
```

Create a DMG and Sparkle appcast for a GitHub Release:

```bash
APP_VERSION=1.0.2 APP_BUILD=3 make appcast
```

For public distribution, sign and notarize the final DMG before generating the appcast signature. If you notarize/staple the DMG separately, reuse that final DMG:

```bash
APP_VERSION=1.0.2 APP_BUILD=3 SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make dmg-universal
# notarize and staple dist/wewi-1.0.2-universal.dmg
APP_VERSION=1.0.2 SKIP_DMG_BUILD=1 make appcast
```

Upload both generated files to the matching GitHub Release tag, e.g. `v1.0.2`:

```text
dist/wewi-1.0.2-universal.dmg
dist/appcast/appcast.xml
```

Useful overrides:

```bash
SPARKLE_FEED_URL=https://example.com/appcast.xml make app
GITHUB_REPOSITORY=elixirevo/wewi RELEASE_TAG=v1.0.2 make appcast
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" make appcast
```

## 🍺 Homebrew Install

Published casks are distributed via the shared tap repository:

- Tap repo: `https://github.com/elixirevo/homebrew-tap`
- Cask token: `wewi`

Install:

```bash
brew tap elixirevo/tap
brew install --cask elixirevo/tap/wewi
```

Local cask test from this repository:

```bash
brew install --cask ./Casks/wewi.rb
```

For maintainers:

1. Create/update release assets on `elixirevo/wewi`.
2. Copy `Casks/wewi.rb` into `elixirevo/homebrew-tap` (`Casks/wewi.rb`).
3. Commit and push the tap update.

## 🧱 Project Structure

```text
Sources/wewi/
  AppDelegate.swift
  LaunchAtLoginManager.swift
  MenuBarController.swift
  SettingsWindowController.swift
  SettingsView.swift
  SettingsComponents.swift
  WidgetConfig.swift
  WidgetStore.swift
  WidgetManager.swift
  WidgetPanelController.swift
  WidgetChromeView.swift
  wewi.swift
scripts/
  build_app.sh
```

## 🔒 Privacy

wewi runs locally on your Mac.
No app telemetry or remote upload is built into the project.
Sparkle update checks fetch the appcast from GitHub Releases.

## 🛠 Contributing

Contributions are welcome.
Please open an issue first for larger changes.

## 📄 License

MIT. See `LICENSE`.
