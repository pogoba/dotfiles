{ pkgs, lib, ... }: let
  mytheme = "glowing";
  wallpaper = builtins.path {
    path = ../users-hm/Jochberg_Nixos_v2.png;
    name = "background.png";
  };
  baseTheme = pkgs.adi1090x-plymouth-themes.override {
    selected_themes = [ mytheme ];
  };
  customTheme = pkgs.runCommand "plymouth-theme-${mytheme}-custom" {} ''
    mkdir -p $out/share/plymouth/themes
    cp -r ${baseTheme}/share/plymouth/themes/${mytheme} $out/share/plymouth/themes/${mytheme}
    chmod -R +w $out

    # Add background wallpaper
    cp ${wallpaper} $out/share/plymouth/themes/${mytheme}/background.png

    # Patch the script to show background image behind the animation
    sed -i '/^screen\.half\.h.*/a\
\
// Background image\
bg_image = Image("background.png");\
bg_image = bg_image.Scale(screen.w, screen.h);\
bg_sprite = Sprite(bg_image);\
bg_sprite.SetPosition(Window.GetX(), Window.GetY(), -100);' \
      $out/share/plymouth/themes/${mytheme}/${mytheme}.script

    # Update .plymouth to point to the new paths
    sed -i "s|ImageDir=.*|ImageDir=$out/share/plymouth/themes/${mytheme}|" \
      $out/share/plymouth/themes/${mytheme}/${mytheme}.plymouth
    sed -i "s|ScriptFile=.*|ScriptFile=$out/share/plymouth/themes/${mytheme}/${mytheme}.script|" \
      $out/share/plymouth/themes/${mytheme}/${mytheme}.plymouth
  '';
in {
  config = {
    boot = {
      plymouth = {
        enable = true;
      theme = mytheme; # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/pkgs/data/themes/adi1090x-plymouth-themes/shas.nix
      themePackages = [ customTheme ]; # https://github.com/adi1090x/plymouth-themes?tab=readme-ov-file#previews
    };
      kernelParams = [
        "quiet"
        "splash"
        "udev.log_level=3"
        "udev.log_priority=3"
        "systemd.show_status=auto"
        "boot.shell_on_fail"
      ];
      # Enable "Silent boot"
      consoleLogLevel = 3;
      initrd.verbose = false;
      initrd.systemd.enable = lib.mkForce true;
    };
  };
}
