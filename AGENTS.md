# wewi

- Keep widget settings compatible with `wewi.widgets.v1` and the existing bundle ID.
- Read `../tools/library/docs/agent-integration.md`, `docs/settings-configuration.md`,
  and `docs/integration.md` (all relative to the library) before changing integration.
- Use MacAppEssentials products for settings, menus, lifecycle, onboarding and services;
  keep widget rendering and storage app-owned. Features belong in `.custom("features")`.
- Legal documents belong in Settings > Help & Support, using bundled read-only sheets
  until actual public URLs exist. Never add separate legal sidebar pages.
- Terms acceptance, onboarding completion and optional crash reporting are independent.
  Do not start widget networking, Sentry or Sparkle before required terms acceptance.
- For Sentry, read `../tools/library/docs/sentry-setup.md`. Use its provision tool and
  developer profile; never print or bundle management tokens. Diagnostics default OFF
  and changes apply on the next launch. Never transmit test crashes without authorization.
- Keep app strings and legal documents in both en/ko, resolved by AppLocalizer.current.
- `--preview` uses a disposable preferences domain and never starts widget networking,
  Sparkle or Sentry. Use it for UI checks without modifying real user data or consent.
- Build with `scripts/build_app.sh`; use full Xcode via DEVELOPER_DIR for `swift test`.
  Validate bundled resources and macOS 13 deployment target separately from the SDK.
