{ flakepkgs, pkgs, ... }:
let
  synatudor = flakepkgs.synatudor-00fd;
in
{
  config = {
    services.fprintd = {
      enable = true;
      tod = {
        enable = true;
        driver = synatudor;
      };
    };

    services.udev.packages = [ synatudor ];
    services.dbus.packages = [ synatudor ];

    systemd.services.tudor-host-launcher = {
      description = "Tudor host launcher DBus service";
      serviceConfig = {
        Type = "dbus";
        BusName = "net.reactivated.TudorHostLauncher";
        ExecStart = "${synatudor}/lib/tudor/tudor_host_launcher";
        WorkingDirectory = "${synatudor}/lib/tudor/";
        StateDirectory = "tudor";
        StateDirectoryMode = "0700";
        ProtectSystem = "strict";
        ProtectKernelTunables = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectKernelModules = true;
        PrivateTmp = true;
        PrivateDevices = true;
        RestrictRealtime = true;
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
