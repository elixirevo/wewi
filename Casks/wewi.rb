cask "wewi" do
  arch arm: "arm64", intel: "x86_64"

  version "1.1.2"
  sha256 arm:   "06fd99643b212af5da5486d00253a8c7dd4b2916e8f230a85d3178f03d285c1e",
         intel: "88ef707a03c78ea231376c4aabbf9fd5a3130b15f4ad2dee4ed02e573722eca2"

  url "https://github.com/elixirevo/wewi/releases/download/v#{version}/wewi-#{version}-#{arch}.dmg"
  name "wewi"
  desc "Pin live web pages to your desktop as widgets"
  homepage "https://github.com/elixirevo/wewi"

  depends_on macos: :ventura

  app "wewi.app"
end
