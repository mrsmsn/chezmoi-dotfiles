{ ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "none";
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
