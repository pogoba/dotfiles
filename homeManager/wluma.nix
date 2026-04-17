# Automatic brightness adjustment via wluma.
# Only works with noctalia (requires a Wayland compositor like niri).
{ config, lib, pkgs, ... }:
{
  options.my-wluma = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      example = true;
      description = "Enable wluma automatic brightness adjustment";
    };
  };

  config = lib.mkIf config.my-wluma.enable {
    home.file.".config/wluma/config.toml".source = ../wluma/config.toml;

    systemd.user.services.wluma = {
      Unit = {
        Description = "wluma automatic brightness adjustment";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = "${pkgs.wluma}/bin/wluma";
        Restart = "on-failure";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
