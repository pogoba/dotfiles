# This module assumes that the gnome.nix module is also included (because we do a lot of generic desktop stuff in there as well)
{ config, pkgs, lib, ... }: {
  options = {
    myKdePlasma = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Whether to enable my KDE Plasma setup instead of GNOME.";
    };
  };

  config = lib.mkIf (config.myKdePlasma) {
    services.displayManager.gdm.enable = lib.mkForce false;
    services.desktopManager.gnome.enable = lib.mkForce false;

    # dark mode
    # wallpaper
    # scroll direction
    # color scheme and window decorations
    services.displayManager.sddm.enable = true;
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    hardware.bluetooth.enable = true;

    environment.systemPackages = with pkgs; [
      gnome-calculator
      nautilus
      openvpn
    ];
  };
}
