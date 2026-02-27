{ inputs, ... }: {
  perSystem = { pkgs, lib, inputs', system, ... }: {
    devShells = {
      default = pkgs.mkShell {
        buildInputs = with pkgs; [
          just
          nix-output-monitor
          inputs'.disko.packages.disko
          # selenium-manager
          chromedriver
          (python3.withPackages (python-pkgs: with python-pkgs; [
            dnspython
            tqdm
            selenium
          ]))
        ];
      };
      clang = pkgs.callPackage ./devShells/clang.nix { inherit pkgs; };
      containers = pkgs.callPackage ./devShells/containers.nix { inherit pkgs; };
      latex = pkgs.callPackage ./devShells/latex.nix { inherit pkgs; tex2nixPkgs = inputs'.tex2nix.packages; };
      networking = pkgs.callPackage ./devShells/networking.nix { inherit pkgs; };
      node = pkgs.callPackage ./devShells/node.nix { inherit pkgs; };
      python = pkgs.callPackage ./devShells/python.nix { inherit pkgs; };
      recording = pkgs.callPackage ./devShells/recording.nix { };
      rust = pkgs.callPackage ./devShells/rust.nix { inherit pkgs; fenixPkgs = inputs'.fenix.packages; };
      sys-stats = pkgs.callPackage ./devShells/sys-stats.nix { inherit pkgs; };
      texra = pkgs.callPackage ./devShells/texra.nix { inherit pkgs; inherit (inputs) nixpkgs; };
    };
  };
  flake = {
    packages.x86_64-linux = {
    };
  };
}
