{ pkgs, lib, ... }: let
  mytheme = "glowing";
in {
  config = {
    boot = {
      plymouth = {
        enable = true;
      theme = mytheme; # https://github.com/NixOS/nixpkgs/blob/nixos-24.05/pkgs/data/themes/adi1090x-plymouth-themes/shas.nix
      themePackages = [
        (pkgs.adi1090x-plymouth-themes.override {
          selected_themes = [ mytheme ];
        })
      ]; # https://github.com/adi1090x/plymouth-themes?tab=readme-ov-file#previews
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
