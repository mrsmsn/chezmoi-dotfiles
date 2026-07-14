{ ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false; # darwin-rebuild switch を brew update で遅くしない
      upgrade = false; # 更新は Cask 自前の auto-update に任せる
      cleanup = "none"; # 手動 brew install を排除しない (Homebrew 移行直後の安全策)
    };

    global.brewfile = true;

    taps = [
      "nikitabobko/tap"
    ];

    brews = [ ];

    casks = [
      "aerospace"
      "ghostty"
      "google-chrome"
      "google-japanese-ime"
      "karabiner-elements"
      "obsidian"
      "raycast"
      "scroll-reverser"
      "slack"
      "tailscale-app"
      "visual-studio-code"
      "wezterm"
    ];
  };
}
