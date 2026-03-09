{ ... }:
{
  specialisation = {
    gnome = {
      inheritParentConfig = true;
      configuration = {
        myKdePlasma.enable = false;
      };
    };
  };
  networking.hostName = "aenderpad"; # Define your hostname.
  networking.hostId = "faae4fe2"; # for zfs
  networking.retiolum = {
    ipv4 = "10.243.29.201";
    ipv6 = "42:0:3c46:2aad:ed1e:33cf:aece:d216";
  };
  networking.firewall.enable = false;
  services.sysprof.enable = true;
}
