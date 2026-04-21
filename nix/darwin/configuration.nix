{ pkgs, ... }:

{
  # Determinate Systems' nix-installer manages Nix via its own daemon
  # (determinate-nixd). nix-darwin refuses to activate when it detects
  # that daemon unless we opt out of its built-in Nix management here.
  # This also means other `nix.*` options (e.g. nix.settings.*) will be
  # no-ops — Determinate Nix handles those settings itself, and flakes
  # are enabled by default.
  nix.enable = false;

  system.stateVersion = 4;

  programs.zsh.enable = true;
}
