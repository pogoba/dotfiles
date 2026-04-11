{ config, lib, pkgs, inputs, ... }:
let
  patchPluginSettings = src: settings:
    if settings == {} then src
    else pkgs.runCommand "${builtins.baseNameOf src}-patched" {} ''
      cp -r ${src} $out
      chmod -R +w $out
      ${pkgs.jq}/bin/jq ${lib.escapeShellArg (
        lib.concatStringsSep " | "
          (lib.mapAttrsToList (k: v: ".metadata.defaultSettings.${k} = ${builtins.toJSON v}") settings)
      )} $out/manifest.json > $out/manifest.json.tmp
      mv $out/manifest.json.tmp $out/manifest.json
    '';
in
{
  options.my-noctalia = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
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

    systemd.user.services.keepassxc = {
      Unit = {
        Description = "KeePassXC password manager";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.keepassxc}/bin/keepassxc";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Ensure XDG autostart apps (Nextcloud, etc.) start after KeePassXC
    # so they can use it as a Secret Service provider.
    home.file.".config/systemd/user/xdg-desktop-autostart.target.d/after-keepassxc.conf".text = ''
      [Unit]
      After=keepassxc.service
      Wants=keepassxc.service
    '';

    home.file.".config/niri/config.kdl".source = ./niri.kdl;
    home.file.".config/noctalia/plugins/display-config".source =
      patchPluginSettings "${inputs.my-noctalia-plugins-src}/display-config" { iconColor = "default"; };
    home.file.".config/noctalia/plugins/khal-next".source =
      patchPluginSettings "${inputs.my-noctalia-plugins-src}/khal-next" { iconColor = "default"; };
    home.file.".config/noctalia/plugins/keybind-cheatsheet".source =
      "${inputs.noctalia-plugins-src}/keybind-cheatsheet";
    home.file.".config/noctalia/plugins/slowbongo".source =
      patchPluginSettings "${inputs.noctalia-plugins-src}/slowbongo" {
        inputDevices = [ "/dev/input/event1" ];
        catSize = 1.5;
      };
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
        keybind-cheatsheet = {
          enabled = true;
          sourceUrl = "";
        };
        slowbongo = {
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

      evtest # dependency for slowbongo plugin
    ];

    # configure options
    programs.noctalia-shell = {
      enable = true;
      systemd.enable = true;
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
              { id = "plugin:keybind-cheatsheet"; }
              { id = "plugin:slowbongo"; }
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
        general.keybinds = {
          keyUp = [ "Up" "Ctrl+P" ];
          keyDown = [ "Down" "Ctrl+N" ];
        };
        location = {
          monthBeforeDay = false;
          name = "Munich, France";
        };
      };
      # this may also be a string or a path to a JSON file.
    };
  };
}
