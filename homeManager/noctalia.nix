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
    # Set the GTK icon theme so Qt's gtk3 platform theme (QT_QPA_PLATFORMTHEME=gtk3)
    # picks up breeze instead of falling back to hicolor.
    gtk = {
      enable = true;
      iconTheme = {
        name = "breeze";
        package = pkgs.kdePackages.breeze-icons;
      };
    };

    home.file.".config/niri/config.kdl".source = ./niri.kdl;
    home.file.".config/noctalia/plugins/display-config".source = "${inputs.noctalia-plugins-src}/display-config";
    home.file.".config/noctalia/plugins/khal-next".source = "${inputs.noctalia-plugins-src}/khal-next";
    home.file.".config/noctalia/plugins.json".text = builtins.toJSON {
      version = 2;
      sources = [
        {
          enabled = true;
          name = "Noctalia Plugins";
          url = "https://github.com/noctalia-dev/noctalia-plugins";
        }
      ];
      states = {
        display-config = {
          enabled = true;
          sourceUrl = "";
        };
        khal-next = {
          enabled = true;
          sourceUrl = "";
        };
      };
    };

    home.packages = with pkgs; [
      jq
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
      # Patch the launcher sort in LauncherCore.qml so open windows always
      # appear above apps. Upstream sorts by `return sb - sa` (descending
      # fuzzy-match _score). We prepend a check and higher priority
      # comparator: wa/wb are 1 for window results (which carry a `windowId`
      # field from WindowsProvider), 0 otherwise.
      package = inputs.noctalia.packages.${pkgs.stdenv.hostPlatform.system}.default.overrideAttrs (old: {
        postFixup = (old.postFixup or "") + ''
          local f=$out/share/noctalia-shell/Modules/Panels/Launcher/LauncherCore.qml
          chmod +w "$f"
          ${pkgs.python3}/bin/python3 -c "
          import sys
          text = open(sys.argv[1]).read()
          text = text.replace(
              'return sb - sa;',
              'const wa = a.windowId !== undefined ? 1 : 0; const wb = b.windowId !== undefined ? 1 : 0; if (wa !== wb) return wb - wa; return sb - sa;'
          )
          open(sys.argv[1], 'w').write(text)
          " "$f"
        '';
      });
      settings = {
        # configure noctalia here
        bar = {
          density = "compact";
          position = "right";
          showCapsule = false;
          widgets = {
            left = [
              {
                formatHorizontal = "HH:mm";
                formatVertical = "HH mm";
                id = "Clock";
                useMonospacedFont = true;
                usePrimaryColor = true;
              }
              {
                id = "plugin:khal-next";
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
              { id = "plugin:display-config"; }
              {
                id = "Tray";
              }
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
                id = "ControlCenter";
                useDistroLogo = true;
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
