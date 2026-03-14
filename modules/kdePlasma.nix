# This module assumes that the gnome.nix module is also included (because we do a lot of generic desktop stuff in there as well)
{ flakepkgs, config, pkgs, lib, ... }: {
  options = {
    myKdePlasma = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Whether to enable my KDE Plasma setup instead of GNOME.";
    };
  };

  config = lib.mkIf (config.myKdePlasma) {
    nixpkgs.overlays = [
      (_final: prev: let
        originalPW = prev.kdePackages.plasma-workspace;
      in {
        kdePackages = prev.kdePackages // {
          plasma-workspace = prev.runCommand "${originalPW.name}-custom-splash" {
            inherit (originalPW) meta version;
            passthru = originalPW.passthru or {};
          } ''
            cp -a ${originalPW} $out
            chmod -R u+w $out
            splashDir=$out/share/plasma/look-and-feel/org.kde.breeze.desktop/contents/splash
            cp ${../pkgs/kde-splash/Splash.qml} $splashDir/Splash.qml
            cp ${builtins.path { path = ../users-hm/Jochberg_Nixos_v2.png; name = "background.png"; }} $splashDir/images/background.png
          '';
        };
      })
    ];
    services.displayManager.gdm.enable = lib.mkForce false;
    services.desktopManager.gnome.enable = lib.mkForce false;

    # dark mode
    # wallpaper
    # scroll direction
    # color scheme and window decorations
    services.displayManager.sddm = {
      enable = true;
      autoLogin.relogin = true;
    };
    services.desktopManager.plasma6.enable = true;
    services.displayManager.sddm.wayland.enable = true;
    hardware.bluetooth.enable = true;

    environment.systemPackages = with pkgs; [
      gnome-calculator
      nautilus
      openvpn
      # flakepkgs.kdeSplashScreen # settings from GUI app don't apply consistently, so we just patch the default theme that plasma fall back to
    ];

    # Fix for LUKS to unlock keyring with auto login. See https://github.com/NixOS/nixpkgs/pull/282317
    # https://github.com/lf-/dotfiles/commit/4eb47c29c4c1707b4f11989de6cae5de3547c3aa
    systemd.services.display-manager = {
      serviceConfig = {
        KeyringMode = "inherit";
      };
    };

    services.displayManager = {
      autoLogin.enable = true;
      autoLogin.user = "peter";
      defaultSession = "plasma";
    };

    security.pam.services.login.enableKwallet = true;
    security.pam.services = {
      sddm-autologin.text = lib.mkForce ''
        auth requisite ${pkgs.linux-pam}/lib/security/pam_nologin.so
        auth optional ${config.systemd.package}/lib/security/pam_systemd_loadkey.so
        auth optional ${pkgs.kdePackages.kwallet-pam}/lib/security/pam_kwallet5.so
        auth required ${pkgs.linux-pam}/lib/security/pam_succeed_if.so uid >= ${toString config.services.displayManager.sddm.autoLogin.minimumUid} quiet
        auth required ${pkgs.linux-pam}/lib/security/pam_permit.so
        account include sddm
        password include sddm
        session include sddm
      '';
    };

  };
}
