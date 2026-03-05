cask "wewi" do
  version "1.0.2"
  sha256 "64576c7fb2b01d08c4aa075c17b3d9273a10ae2236c26e2c274c7a40857ddf7a"

  url "https://github.com/elixirevo/wewi/releases/download/v#{version}/wewi-#{version}-universal.dmg"
  name "wewi"
  desc "Pin live web pages to your macOS desktop as widgets"
  homepage "https://github.com/elixirevo/wewi"

  app "wewi.app"
end
