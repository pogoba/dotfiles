{ self, inputs, ...}: {
  perSystem = { pkgs, ... }: {
    packages = {
      map-cmd = pkgs.callPackage ./pkgs/map.nix { };
      loc-git = pkgs.callPackage ./pkgs/loc.nix { inherit (inputs) loc-src; };
      nixos-generations = pkgs.callPackage ./pkgs/nixos-generations.nix { };
      nixos-specializations = pkgs.callPackage ./pkgs/nixos-specializations.nix { };
      self-flake = pkgs.callPackage ./pkgs/self-flake.nix { inherit self; impure-debug-info = inputs.impurity; };
      nix-patched = pkgs.callPackage ./pkgs/nix-patched.nix { };
      wondershaper = pkgs.callPackage ./pkgs/wondershaper.nix { inherit (inputs) wondershaper-src; };
      jack-keyboard = pkgs.callPackage ./pkgs/jack-keyboard.nix { };
      nss-passwords = pkgs.callPackage ./pkgs/nss-passwords.nix { };
      sonixflasherc = pkgs.callPackage ./pkgs/sonixflasherc.nix { };
      qmk_firmware_k3 = pkgs.callPackage ./pkgs/qmk_firmware.nix { };
      revanced-cli = pkgs.callPackage ./pkgs/revanced-cli.nix { };
      #wluma = pkgs.callPackage ./pkgs/wluma.nix { };
      #webcord = if "${system}" == "x86_64-linux" then pkgs.callPackage ./pkgs/webcord-appimage.nix { } else null;
      #webcord = pkgs.callPackage ./pkgs/webcord-appimage.nix { };
      nix-top = pkgs.nix-top.overrideAttrs (finalAttrs: previousAttrs: {
        # my nix-top fork
        src = inputs.nix-top-src;
      });
      qemu-test = pkgs.qemu.overrideAttrs (old: new: {
        version = "9.2.0";
        src = pkgs.fetchurl {
          url = "https://download.qemu.org/qemu-${new.version}.tar.xz";
          hash = "sha256-Gf2ddTWlTW4EThhkAqo7OxvfqHw5LsiISFVZLIUQyW8=";
        };
      });
      build-linux = pkgs.vmTools.runInLinuxVM pkgs.linuxPackages.kernel;
      core-to-core-latency = pkgs.callPackage ./pkgs/core-to-core-latency/default.nix { };
      kdeSplashScreen = pkgs.callPackage ./pkgs/kde-splash { };
    };
  };
  flake = let
    pkgs = inputs.nixpkgs.legacyPackages.x86_64-linux;
    make-disk-image = import (./nix/make-disk-image.nix);
  in {
    packages.x86_64-linux = {
      webcord = pkgs.callPackage ./pkgs/webcord-appimage.nix { };
      # cider = pkgs.callPackage pkgs/cider.nix { }; # depricated
      kobo-book-downloader = pkgs.callPackage pkgs/kobo-book-downloader.nix { };
      # broken/in development:
      # apple-music = pkgs.callPackage pkgs/apple-music.nix { };
      test = pkgs.callPackage ./pkgs/test.nix { };
    };
  };
}
