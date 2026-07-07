{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    noto-fonts
    noto-fonts-cjk-sans
    noto-fonts-cjk-serif
    noto-fonts-color-emoji
    hackgen-font
    hackgen-nf-font
  ];

  fonts.fontDir.enable = true;

  fonts.fontconfig.defaultFonts = {
    serif     = [ "Noto Serif CJK JP" "Noto Color Emoji" ];
    sansSerif = [ "Noto Sans CJK JP" "Noto Color Emoji" ];
    monospace = [ "HackGen Console NF" "Noto Color Emoji" ];
    emoji     = [ "Noto Color Emoji" ];
  };
}
