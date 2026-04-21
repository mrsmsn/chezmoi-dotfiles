{ pkgs, ... }:

{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = 4;

  # Back up conflicting /etc/* files (e.g. Homebrew-installed /etc/zshrc)
  # instead of aborting activation on first `darwin-rebuild switch`.
  system.backupFileExtension = "backup";

  programs.zsh.enable = true;
}
