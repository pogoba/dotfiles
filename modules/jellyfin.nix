{ pkgs, ... }: {
  config = {
    services.jellyfin = {
      enable = true;
      user = "peter";
    };
    systemd.services.jellyfin-mnt = {
      enable = true;
      before = [ "jellyfin.service" ];
      script = "mkdir -p /mnt && ${pkgs.util-linux}/bin/mountpoint -q /mnt || /run/wrappers/bin/sudo /run/wrappers/bin/mount -t cifs -o username=Anonymous //$(${pkgs.host}/bin/host -t A yellow.r | ${pkgs.gawk}/bin/awk '{ print $4 }')/public/ /mnt";
      serviceConfig.Type = "oneshot";
    };
    systemd.services.jellyfin = {
      wantedBy = pkgs.lib.mkForce [];
      requires = [ "jellyfin-mnt.service" ];
    };
    environment.systemPackages = [
      pkgs.jellyfin
      pkgs.jellyfin-web
      pkgs.jellyfin-ffmpeg
    ];
  };
}
