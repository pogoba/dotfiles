{ config, lib, pkgs, ... }:
{
  options.my-gui = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      example = false;
      description = "Add home config for environments with graphical user interfaces";
    };
  };

  config = lib.mkIf config.my-gui.enable {
    home.file.".imapfilter/config.lua".source = ./imapfilter.lua;

    home.packages = with pkgs; [
      imapfilter
      #(weechat.override {
      #  configure = { availablePlugins, ... }: {
      #    scripts = with pkgs.weechatScripts; [
      #      weechat-otr
      #      wee-slack
      #      multiline
      #      weechat-matrix
      #    ];
      #    plugins = [
      #      availablePlugins.python
      #      availablePlugins.perl
      #      availablePlugins.lua
      #    ];
      #  };
      #})
    ];

    programs.chromium = {
      enable = true;
      extensions = [
        { id = "cfhdojbkjhnklbpkdaibdccddilifddb"; } # adblock plus
        { id = "dbepggeogbaibhgnhhndojpepiihcmeb"; } # vimium
      ];
    };

    programs.firefox = {
      enable = true;
      # Extra preferences to add to user.js: extraConfig = "";
      # After manually setting settings, this will fail to apply.
      # profiles.default = {
      #    # Note that it is necessary to manually enable these extensions inside Firefox after the first installation.
      #   extensions = [
      #     pkgs.nur.repos.rycee.firefox-addons.vimium
      #   ];
      #   search.default = "DuckDuckGo";
      #   # settings = {  }; see about config
      # };
    };

    # programs.zed-editor = {
    #   enable = true;
    #   extensions = [
    #     "nix"
    #     "lua"
    #     "latex"
    #   ];
    # };

    home.file.".config/alacritty/alacritty.colors.toml".source = ./alacritty.colors.toml;
    home.file.".config/alacritty/alacritty.toml".source = ./alacritty.toml;

    home.file.".config/ghostty/config".source = ./ghostty.config;

    # KDE splash screen theme (symlink to nix store = KDE can't overwrite it)
    home.file.".config/ksplashrc".text = ''
      [KSplash]
      Theme=org.custom.jochberg.desktop
    '';

    # nah doesnt work. Rather just place according files in ~/.config/autostart like gnome-tweaks does
    # systemd.user.services = {
    #   calendar = {
    #     Unit = {
    #       Description = "Foobar";
    #     };
    #     Service = {
    #       Type = "simple";
    #       ExecStart = "${pkgs.gnome.gnome-calendar}/bin/gnome-calendar";
    #     };
    #     Install = {
    #       WantedBy = ["graphical-session.target"];
    #     };
    #   };
    # };

    # a tutorial on declarative gnome configuration
    # https://determinate.systems/posts/declarative-gnome-configuration-with-nixos

    # Use `dconf watch /` to track stateful changes you are doing, then set them
    # here.
    dconf.settings = with lib.hm.gvariant; {
      "system/locale" = {
        region = "en_GB.UTF-8";
      };
      "org/gnome/desktop/input-sources" = {
        per-window = true;
        sources = (mkArray (type.tupleOf [ type.string type.string ]) [
          (mkTuple ["xkb" "us"])
          (mkTuple ["xkb" "de"])
        ]);
      };
      "org/gnome/desktop/wm/keybindings" = {
        # alt tab should switch windows not applications
        switch-applications = [];
        switch-applications-backward = [];
        #switch-group = [ "<Super>`" "<Alt>`" ];
        #switch-group-backward = [ "<Shift><Super>`" "<Shift><Alt>`" ];
        switch-windows = [ "<Super>Tab" "<Alt>Tab" ];
        switch-windows-backward = [ "<Shift><Super>Tab" "<Shift><Alt>Tab" ];
      };
      "org/gnome/desktop/interface" = {
        color-scheme = "prefer-dark";
      };
      "org/gnome/shell" = {
        favorite-apps = [
          "org.gnome.Nautilus.desktop"
          "firefox.desktop"
          "chromium-browser.desktop"
          "Alacritty.desktop"
          "org.gnome.Geary.desktop"
          "org.signal.Signal.desktop"
          "org.telegram.desktop.desktop"
          "slack.desktop"
          "gnome-system-monitor.desktop"
          "org.gnome.Settings.desktop"
          "org.gnome.tweaks.desktop"
        ];
      };
      # "org/gnome/desktop/background" = {
      #   picture-uri = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-l.png";
      #   picture-uri-dark = "file:///run/current-system/sw/share/backgrounds/gnome/vnc-d.png";
      # };
      "org/gnome/shell" = {
        # `gnome-extensions list` for a list
        enabled-extensions = [
          "appindicatorsupport@rgcjonas.gmail.com"
          "bluetooth-quick-connect@bjarosze.gmail.com"
          "ctile@pogobanane.de"
          "noannoyance@daase.net"
          "switcher@landau.fi"
          "workspace-indicator@gnome-shell-extensions.gcampax.github.com"
        ];
        #disable-user-extensions = false;
      };
      "org/gnome/shell/extensions/switcher" = {
        on-active-display = true;
        matching = mkUint32 0; # 0: strict, 1: fuzzy
        # make it a bit smaller
        font-size = mkUint32 28;
        max-width-percentage = mkUint32 69;
      };
    };
  };
}
