{ lib, pkgs, flakepkgs, inputs, ... }: with lib; {

  imports = [
    ./pipewire-audio.nix
    ./jack.nix
  ];

  environment.sessionVariables = {
    QT_QPA_PLATFORM = "wayland"; # qt apps disable wayland by default
    XDG_SESSION_TYPE = "wayland";
    MOZ_ENABLE_WAYLAND = "1"; # mozillas wayland backend is experimental and disabled by default
    NIXOS_OZONE_WL = "1"; # enables wayland for chrome/electron since nixos 22.11
  };
  nixpkgs.overlays = let
    unstableExtensions = inputs.unstablepkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system}.gnomeExtensions;
    majorGnomeVersion = lib.lists.head (lib.strings.splitString "." pkgs.gnome-shell.version);
    update = extension: (extension.overrideAttrs (_finalAttrs: _previousAttrs: rec {
      buildInputs = [ pkgs.jq ];
      postPatch = ''
        # substituteInPlace metadata.json \
        #   --replace '"42"' '"${majorGnomeVersion}", "42"'
        jq '.["shell-version"] = ["${majorGnomeVersion}"]' metadata.json > metadata.json.tmp && mv metadata.json.tmp metadata.json
      '';
    }));
  in [
    (_self: super: {
     #  gnomeExtensions = unstableExtensions // rec {
	    #   switcher-patched = unstableExtensions.switcher.overrideAttrs (_finalAttrs: _previousAttrs: rec {
		   #    src = pkgs.fetchFromGitHub {
			  #     owner = "schrieveslaach";
			  #     repo = "switcher";
			  #     rev = "3dcd662682d493e9352c15f3f38464617f513ae2";
			  #     sha256 = "sha256-Byuj3pRav6+yJifR6OP8DO30ccZaxVf/ome6rwHfD8s=";
		   #    };
	    #   });
	    # };
      gnomeExtensions = super.gnomeExtensions // rec {
        #switcher = gsuper.switcher.overrideAttrs (finalAttrs: previousAttrs: {
        # switcher-patched = super.pkgs.gnomeExtensions.switcher;
        switcher-patched = update super.pkgs.gnomeExtensions.switcher;
      };
    })
  ];
  # chromium --enable-features=UseOzonePlatform --ozone-platform=wayland
  # opening chrome://flags/#enable-webrtc-pipewire-capturer in chrome and change "WebRTC PipeWire support" to "Enabled" makes screen sharing work
  # not there yet: flatpak run --env=XDG_SESSION_TYPE=wayland --env=QT_QPA_PLATFORM=wayland --socket=wayland --enable-features=UseOzonePlatform --ozone-platform=wayland io.typora.Typora

  environment.systemPackages = with pkgs; [
    # fprintd # seems to brick the login screen on ThinkPad E14 amd
    nextcloud-client
    gnome-terminal
    gedit
    seahorse
    remmina # rdp/vnc client
    ctile
    gnomeExtensions.appindicator
    gnomeExtensions.switcher-patched
    # gnomeExtensions.tactile
    # gnomeExtensions.noannoyance-fork
    gnomeExtensions.forge
    gnomeExtensions.ssh-search-provider-reborn
    gnomeExtensions.resource-monitor
    # not as well wtf it should be
    # gnomeExtensions.noannoyance
    # gnomeExtensions.application-volume-mixer
    # gnomeExtensions.run-or-raise
    # not available on gnome 41
    #gnomeExtensions.clock-override
    #gnomeExtensions.wintile-windows-10-window-tiling-for-gnome
    gnome-tweaks
    keepassxc
    bitwarden-desktop

    # terminal emulators:
    alacritty
    wezterm
    # inputs.ghostty.packages.${pkgs.system}.default
    ghostty

    vlc
    libreoffice
    gimp
    gthumb # photo folder viewer
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
    marktext # markdown editor
    # logseq # markdown editor
    dbeaver-bin
    gitg
    zed-editor
    rstudio
    pavucontrol
    libheif # for apple media codecs
    # cider # broken
    audacity
    webcord
    discord
    slack
    signal-desktop
    zulip
    ferdium # one electron to contain all messengers
    # pretty ebook reader with one bug that has a workaround https://github.com/johnfactotum/foliate/issues/719#issuecomment-830874744
    foliate
    # big plugin ecosystem for ebooks. Has a plugin that supposedly works to read and back up Kobo (rakuten) and some amazon ebooks: https://github.com/apprenticeharper/DeDRM_tools
    calibre
    # cli tool to log in and back up Kobo (rakuten) ebooks:
    # flakepkgs.kobo-book-downloader
    ausweisapp
    via # for qmk keyboard flashing
    zotero # academic paper manager. Useful plugin: https://retorque.re/zotero-better-bibtex/exporting/auto/index.html

    inputs.nix-gaming.packages.${pkgs.stdenv.hostPlatform.system}.osu-lazer-bin

    # teamspeak
    #teamspeak_client
    #libsForQt5.qtwayland
    #libsForQt5.plasma-wayland-protocols
    # broken on wayland right now
    atlauncher

    # for iphone
    libimobiledevice
    idevicerestore
    ifuse
    libheif
  ];
  # geary sucks. Or does it?
  # environment.gnome.excludePackages = with pkgs; [ gnome.geary ];
  services.udev.packages = with pkgs; [ gnome-settings-daemon ];
  # allow fractional scaling:
  # gsettings set org.gnome.mutter experimental-features "['scale-monitor-framebuffer']"

  # fix for many rust based guis on wayland/gnome/nixos
  # https://github.com/alacritty/alacritty/issues/4780#issuecomment-890408502
  # https://github.com/NixOS/nixpkgs/issues/22652#issuecomment-890512607
  # TODO this does not arrive yet inside the gnome session
  environment.variables.XCURSOR_THEME = "Adwaita";

  # for iphone
  services.usbmuxd.enable = true;

  services.xserver.enable = true;
  services.displayManager.gdm.enable = lib.mkDefault true;
  services.desktopManager.gnome.enable = lib.mkDefault true;
  services.gnome.gcr-ssh-agent.enable = lib.mkForce false; # no, dear god, no!

  # printing:
  services.printing.enable = true;
  services.printing.drivers = [ pkgs.gutenprint ]; # often replaces hplip

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
    # shairport-sync
    5000
    6000
    6001
    6002
    6003
  ];
  networking.firewall.allowedUDPPorts = [
    5353 # avahi
    # shairport-sync
    5000
    6000
    6001
    6002
    6003
  ];
}
