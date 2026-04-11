# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, flakepkgs, ... }: {
  imports =
    [
      inputs.sops-nix.nixosModules.sops
      inputs.retiolum.nixosModules.retiolum
      inputs.retiolum.nixosModules.ca
      #lambda-pirate.nixosModules.knative
      #lambda-pirate.nixosModules.vhive
      inputs.home-manager.nixosModules.home-manager {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.extraSpecialArgs = {
          inherit (inputs) sops-nix;
          inherit (inputs) nix-index-database;
          inherit (inputs) nur;
          inherit (inputs) nixpkgs;
          inherit (inputs) astro-nvim;
          inherit inputs;
          inherit flakepkgs;
          username = "peter";
          homeDirectory = "/home/peter";
          my-gui = true;
        };
        home-manager.users.peter = import ./homeManager/peter.nix;
      }
      ./modules/self.nix
      ./modules/nix-pkgs.nix
      ./modules/logger.nix
      ./modules/dnsmasq.nix
      ./modules/tor-ssh.nix
      ./modules/remote-builder.nix
      ./modules/zsh.nix
      ./modules/libreweb/libreweb.nix
      ./modules/make-linux-fast.nix
      ./modules/musician.nix
    ];

  #sops.defaultSopsFile = ./secrets.yaml;
  #sops.secrets.testsecret = {
  #path = "/home/peter/.ssh/testsecret";
  #owner = "peter";
  #};

  fonts.packages = with pkgs.nerd-fonts; [
    fira-code
    droid-sans-mono
  ];


  specialisation = {
    upstream = {
      inheritParentConfig = true;
      configuration = {
        # revert to when it (5.19) is compatible with zfs again
        # see linuxPackages_latest.zfs.meta.broken
        #boot.kernelPackages = pkgs.zfs.latestCompatibleLinuxPackages;
        #boot.kernelPackages = pkgs.linuxPackages_6_1;
        boot.kernelPackages = pkgs.linuxPackages_latest;
      };
    };
    #iorefd = {
    #inheritParentConfig = true;
    #configuration = {
    #boot.kernelPackages = pkgs.callPackage ./linux-ioregionfd.nix {};
    #};
    #};
  };

  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  networking.libreweb = true;

  # Set your time zone.
  # time.timeZone = "Europe/Amsterdam";

  # use networkmanager with a local systemd-resolved as DNS server.
  networking.networkmanager.enable = true;
  systemd.network.enable = true;
  services.resolved.enable = true;
  services.resolved.dnssec = "false";

  # The global useDHCP flag is deprecated, therefore explicitly set to false here.
  # Per-interface useDHCP will be mandatory in the future, so this generated config
  # replicates the default behaviour.
  networking.useDHCP = false;
  #networking.interfaces.eth0.useDHCP = true;
  #networking.interfaces.eth0.macAddress = "94:05:bb:11:4e:80";
  #networking.interfaces.eth1.useDHCP = true;
  #networking.interfaces.eth1.macAddress = "94:05:bb:11:3e:80";
  #networking.interfaces.wlan0.useDHCP = true;
  # bridge for qemu VMs
  #networking.bridges."VMs".interfaces = [ "enp4s0f3u1u1" ];
  environment.etc."qemu/bridge.conf" = {
    user = "root";
    group = "qemu";
    mode = "640";
    text = "allow all";
  };

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_DK.UTF-8"; # doesnt seem to fix the perl warnings during nixos-rebuild switch
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "en_GB.UTF-8/UTF-8"
    "de_DE.UTF-8/UTF-8"
    "en_DK.UTF-8/UTF-8"
  ];
  # console = {
  #   font = "Lat2-Terminus16";
  #   keyMap = "us";
  # };
  time.timeZone = "Europe/Berlin";

  # Enable the X11 windowing system.
  # services.xserver.enable = true;




  # Configure keymap in X11
  # services.xserver.layout = "us";
  # services.xserver.xkbOptions = "eurosign:e";

  # Enable CUPS to print documents.
  # services.printing.enable = true;

  # Enable sound.
  # sound.enable = true;
  # hardware.pulseaudio.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  # users.users.jane = {
  #   isNormalUser = true;
  #   extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
  # };
  users.users.peter = {
    isNormalUser = true;
    home = "/home/peter";
    shell = pkgs.zsh;
    extraGroups = [ "wheel" "docker" "input" "cdrom"];
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDITBcN9iw5Fn7yyfgiWFet3QWDoMcUNtzLi+PNoYS7jksvcKZy5pLOjE6wCpkbYx+Tcb4MyvoWPXvwdo5FfL4XdhZRO+JlZ66p/rGssq/wEr2BBUwohP7o39JLtiyXGXSsK6MO2aceOFLQr4KAdaeD8ST0XumGcV6bGqIbjFsK5FCxFhO8NkCFtavBjDwKUm3uyOnVCWMp12abUphzxrVtWhcsnw5GapohATP03mCNxmrn/L7x393HutxgjyduScX7++MjwVE6J7wCnztPUtJbh9jYemr/K9fBMBbLhQagOjrlQYGU5frgmLrPCRZusyg5HjWx6gJIxs/DskfgmW+V peter@aenderarch" # gitpogobanane
    ];
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.daemon.settings = {
    # default ip range for docker bridges seems to be 172.18.0.1.
    # This collides with ip addresses of wifis in DB ICEs trains.
    bip = "172.19.0.1/16";
  };

  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=15
  '';

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    vim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    wget
    git
    ethtool
    htop
    iotop
    lsd
    tokei
    #(pkgs.nerdfonts.override {
    #    fonts = ["FiraCode"];
    #})
    gamescope # util for proton games steam
    flakepkgs.wondershaper
    gamemode
  ];

  # Since git version 2.33.3, it fails when operating on a repo of
  # another user. When `nixos-rebuild switch` is run as root, but the config
  # repo is owned by a normal user, this error occurs. Therefore we set an
  # exception for that folder here.
  environment.etc.gitconfig.text = ''
    [safe]
      directory = /home/peter/dev/dotfiles
  '';

  # not flake ready
  programs.command-not-found.enable = false;

  #programs.sysdig.enable = true;

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };
  programs.zsh.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
  };

  hardware.keyboard.qmk.enable = true;
  services.udev.extraRules = ''
    # my/SonixQMK firmware for keychron k3
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="fe04", TAG+="uaccess"
    # seyahdoo's qmk firmware for keychron k3
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="3434", ATTRS{idProduct}=="fe05", TAG+="uaccess"
    # SN32F248 bootloader on keychron k3
    SUBSYSTEMS=="usb", ATTRS{idVendor}=="0C45", ATTRS{idProduct}=="7040", TAG+="uaccess"
  '';

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  services.openssh.enable = true;
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.PermitRootLogin = "no";
  programs.ssh = {
    startAgent = true;
  };


  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = lib.mkDefault true;
  systemd.services.systemd-networkd-wait-online.enable = lib.mkForce false;
  systemd.services.NetworkManager-wait-online.enable = false;

  boot.supportedFilesystems = [ "ntfs" ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # THIs value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "21.11"; # Did you read the comment?

}
