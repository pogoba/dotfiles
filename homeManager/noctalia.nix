{ config, lib, pkgs, inputs, ... }:
{
  options.my-noctalia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Add home config for noctalia shell for niri";
    };
  };

  config = lib.mkIf config.my-noctalia.enable {
    home.file.".config/niri/config.kdl".source = ./niri.kdl;

    home.packages = with pkgs; [
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

    # configure options
    programs.noctalia-shell = {
      enable = true;
      settings = {
        # configure noctalia here
        bar = {
          density = "compact";
          position = "right";
          showCapsule = false;
          widgets = {
            left = [
              {
                id = "ControlCenter";
                useDistroLogo = true;
              }
              {
                id = "Notifications";
              }
            ];
            center = [
              {
                hideUnoccupied = false;
                id = "Workspace";
                labelMode = "none";
              }
            ];
            right = [
              {
                id = "Network";
              }
              {
                id = "Volume";
              }
              {
                alwaysShowPercentage = true;
                id = "Battery";
                warningThreshold = 30;
              }
              {
                formatHorizontal = "HH:mm";
                formatVertical = "HH mm";
                id = "Clock";
                useMonospacedFont = true;
                usePrimaryColor = true;
              }
            ];
          };
        };
        controlCenter.shortcuts = {
          left = [
            { id = "Network"; }
            { id = "Bluetooth"; }
            { id = "PowerProfile"; }
            { id = "NoctaliaPerformance"; }
          ];
          right = [
            { id = "Notifications"; }
            { id = "NightLight"; }
            { id = "DarkMode"; }
            { id = "Brightness"; }
          ];
        };
        controlCenter.cards = [
          { enabled = true; id = "profile-card"; }
          { enabled = true; id = "shortcuts-card"; }
          { enabled = true; id = "audio-card"; }
          { enabled = true; id = "brightness-card"; }
          { enabled = true; id = "media-sysmon-card"; }
        ];
        colorSchemes.predefinedScheme = "Gruvbox";
        wallpaper.directory = "${../users-hm}";
        # general = {
        #   avatarImage = "/home/drfoobar/.face";
        #   radiusRatio = 0.2;
        # };
        location = {
          monthBeforeDay = false;
          name = "Munich, France";
        };
      };
      # this may also be a string or a path to a JSON file.
    };
  };
}
