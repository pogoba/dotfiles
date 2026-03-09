{ self, inputs, ... }:
let
  system = "x86_64-linux";
  pkgs = inputs.nixpkgs.legacyPackages.${system};
  flakepkgs = self.packages.${system};
  extraArgs = [
    ({ pkgs, ... }: {
      config._module.args = {
        # This is the new, hip extraArgs.
        inherit flakepkgs;
      };
    })
  ];
  specialArgs = {
    inherit inputs;
    inherit self;
  };
  nixosSystem = inputs.nixpkgs.lib.nixosSystem;
in
{
  # TODO: merge this file somehow with the home config as stated in configuration.nix
  systems = [ system ];
  perSystem = { self', pkgs, ... }: {
    apps = {
      # today i had to fix stuff using:
      # sudo mkdir -m 0755 -p /nix/var/nix/{profiles,gcroots}/per-user/$USER
      # sudo chown -R $USER /nix/var/nix/{profiles,gcroots}/per-user/$USER
      doctor-home =
        let
          activation-script = pkgs.writeShellScript "activate" ''
            ${inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager}/bin/home-manager --option keep-going true --flake "${self}#peter-doctor-cluster" "$@"
          '';
        in
        {
          type = "app";
          program = "${activation-script}";
        };
    };
    #packages = {
    #  flake-app-doctor-home = pkgs.writeScriptBin "flake-app-doctor-home" ''
    #    ${self.homeConfigurations.peter-doctor-cluster.activationPackage}/activate
    #  '';
    #};
  };
  flake = {
    homeConfigurations.peter = inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./homeManager/peter.nix
      ];
      extraSpecialArgs = {
        inherit inputs;
        inherit (inputs) astro-nvim;
        inherit flakepkgs;
        username = "peter";
        homeDirectory = "/home/peter";
        my-gui = true;
      };
    };

    homeConfigurations.peter-doctor-cluster = inputs.home-manager.lib.homeManagerConfiguration {
      inherit pkgs;
      modules = [
        ./homeManager/peter.nix
      ];
      extraSpecialArgs = {
        inherit inputs;
        inherit (inputs) astro-nvim;
        inherit flakepkgs;
        username = "okelmann";
        homeDirectory = "/home/okelmann";
        my-gui = false;
      };
    };

    nixosConfigurations.aendernix = nixosSystem {
      system = "x86_64-linux";
      modules = extraArgs ++ [
        ./modules/hardware/hardware-aendernix.nix
        ./aendernix.nix
        ./config-common.nix
        ./modules/gnome.nix
        ./modules/android-dev.nix
      ];
      inherit specialArgs;
    };

    nixosConfigurations.aenderpad = nixosSystem {
      system = "x86_64-linux";
      modules = extraArgs ++ [
        ./modules/hardware/hardware-aenderpad.nix
        ./aenderpad.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-e14-amd
        ./config-common.nix
        ./modules/gnome.nix
        ./modules/kdePlasma.nix # overrides for gnome.nix to use KDE instead
        ./modules/nokia.nix
      ];
      inherit specialArgs;
    };

    # nixosConfigurations.aendernext = nixosSystem {
    #   system = "x86_64-linux";
    #   modules = extraArgs ++ [
    #     ./modules/hardware/hardware-aendernext.nix
    #     ./aenderpad.nix
    #     ./config-common.nix
    #   ];
    #   inherit specialArgs;
    # };

  };
}
