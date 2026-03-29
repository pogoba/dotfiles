{ lib, pkgs, inputs, ... }:

{
  imports = [
    ./pipewire-audio.nix
    ./jack.nix
  ];

  # disable gnome stuff
  services.displayManager.gdm.enable = lib.mkDefault false;
  services.desktopManager.gnome.enable = lib.mkDefault false;
  services.gnome.gcr-ssh-agent.enable = lib.mkForce false; # no, dear god, no!
  

  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland";
    XDG_SESSION_TYPE = "wayland";
    MOZ_ENABLE_WAYLAND = "1";
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    nextcloud-client
    remmina
    keepassxc
    bitwarden-desktop

    # terminal emulators:
    alacritty
    wezterm
    ghostty

    vlc
    libreoffice
    gimp
    gthumb
    inkscape
    rawtherapee
    drawio
    thunderbird
    evince
    pdfarranger
    hexchat
    zoom-us
    element-desktop
    languagetool
    mumble
    marktext
    dbeaver-bin
    gitg
    zed-editor
    rstudio
    pavucontrol
    libheif
    audacity
    webcord
    discord
    slack
    signal-desktop
    zulip
    ferdium
    foliate
    calibre
    ausweisapp
    via
    zotero

    inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.osu-lazer-bin

    atlauncher

    # for iphone
    libimobiledevice
    idevicerestore
    ifuse
    libheif

    gnome-calculator
    eog # gnome image viewer
    gnome-system-monitor
    nautilus
  ];

  # for iphone
  services.usbmuxd.enable = true;

  services.desktopManager.cosmic.enable = true;
  services.displayManager.cosmic-greeter.enable = true;

  # printing:
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint ];

  services.flatpak.enable = true;

  systemd.services.audio-off = {
    description = "Mute audio before suspend";
    wantedBy = [ "sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      Environment = "XDG_RUNTIME_DIR=/run/user/1000";
      User = "joerg";
      RemainAfterExit = "yes";
      ExecStart = "${pkgs.pamixer}/bin/pamixer --mute";
    };
  };

  networking.firewall.allowedTCPPorts = [
    5353 # avahi
    5000 6000 6001 6002 6003 # shairport-sync
  ];
  networking.firewall.allowedUDPPorts = [
    5353 # avahi
    5000 6000 6001 6002 6003 # shairport-sync
  ];
}
