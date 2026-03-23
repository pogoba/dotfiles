{ pkgs }:

let
  wallpaper = builtins.path {
    path = ../users-hm/Jochberg_Nixos_v2.png;
    name = "background.png";
  };
in pkgs.runCommand "grub-theme-jochberg" {
  nativeBuildInputs = [ pkgs.imagemagick ];
} ''
  mkdir -p $out

  # Background: scale to common GRUB resolution
  magick ${wallpaper} -resize 1920x1200! $out/background.png

  # Theme definition
  cat > $out/theme.txt <<'THEME'
  # Global properties
  title-text: ""
  desktop-image: "background.png"
  desktop-color: "#000000"
  terminal-font: "Unifont Regular 16"
  terminal-left: "0"
  terminal-top: "0"
  terminal-width: "100%"
  terminal-height: "100%"
  terminal-border: "0"

  # Boot menu
  + boot_menu {
    left = 30%
    top = 30%
    width = 40%
    height = 40%
    item_font = "Unifont Regular 16"
    item_color = "#cccccc"
    selected_item_font = "Unifont Regular 16"
    selected_item_color = "#ffffff"
    item_height = 24
    item_padding = 4
    item_spacing = 4
    icon_width = 0
    icon_height = 0
    scrollbar = false
  }

  # Countdown label
  + label {
    left = 30%
    top = 72%
    width = 40%
    align = "center"
    id = "__timeout__"
    text = "Booting in %d seconds"
    color = "#cccccc"
    font = "Unifont Regular 14"
  }
  THEME
''
