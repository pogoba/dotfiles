{ ... }: let
  # on recent nixos25.11, obs-vertical-canvas is broken. This is an older version where it still works.
  pkgs = (builtins.getFlake "github:nixos/nixpkgs/a3068ebb668fc855d16101b1f0c8ec82e1a83635").legacyPackages.x86_64-linux;
in
  pkgs.mkShell {
    buildInputs = [
      kdePackages.kdenlive # maybe better use the flatpak version. It doesnt crash when saving the project.
      (pkgs.wrapOBS {
        plugins = with pkgs.obs-studio-plugins; [
          # wlrobs
          obs-backgroundremoval
          # obs-pipewire-audio-capture
          obs-vaapi #optional AMD hardware acceleration
          # obs-gstreamer
          # obs-vkcapture
          # obs-aitum-multistream
          obs-vertical-canvas
        ];
      })
    ];
  }
