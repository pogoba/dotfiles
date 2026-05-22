# known working: 
#  - turn on VPN/be at uni
#  - `sudo nixos-rebuild build` to use a clean ssh config.
#  - untested: perms on ssh key?
#  - untested: does nixos cache knowledge about unsuable remotes builders?
{ ...}: {
  nix.distributedBuilds = true;
  nix.extraOptions = ''
    builders-use-substitutes = true
  '';
  programs.ssh.extraConfig = ''
    Host builder-jumphost
      User tunnel
      HostName login.dos.cit.tum.de
      IdentityFile /home/peter/.ssh/doctorBuilder

    Host graham-builder-via-jumphost
      HostName graham.dse.in.tum.de
      ProxyJump builder-jumphost

    Host rose-builder-via-jumphost
      HostName rose.dse.in.tum.de
      ProxyJump builder-jumphost
  '';
  programs.ssh.knownHosts = {
    "login.dos.cit.tum.de" = {
      hostNames = [ "login.dos.cit.tum.de" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJiLBCN41dSG/45o5/h/56VF02nRVWe2ssTbE7VrxZOA";
    };
    "graham.dse.in.tum.de" = {
      hostNames = [ "graham.dse.in.tum.de" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMhxrYxHNgOvaLH6fVGNG3F8/TNDP1xqUXymQBykV4b0 root@nixos";
    };
    "rose.dse.in.tum.de" = {
      hostNames = [ "rose.dse.in.tum.de" ];
      publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGXKWTYVfN/MPqNaypMktG50H5x4Aqs5Fdlv0bUhzii7";
    };
  };
  nix.buildMachines = [
    #{
    #  speedFactor = 0;
    #  hostName = "ryan.dse.in.tum.de";
    #  sshUser = "ssh-ng://nix";
    #  sshKey = "/home/peter/.ssh/doctorBuilder"; # TODO use sops
    #  #sshKey = "/tmp/doctorBuilder";
    #  system = "x86_64-linux";
    #  maxJobs = 64;
    #  supportedFeatures = [
    #    "big-parallel"
    #    "kvm"
    #    "nixos-test"
    #  ];
    #}
    # {
    #   speedFactor = 0;
    #   hostName = "graham-builder-via-jumphost";
    #   protocol = "ssh";
    #   sshUser = "nix";
    #   sshKey = "/home/peter/.ssh/doctorBuilder"; # TODO use sops
    #   system = "x86_64-linux";
    #   maxJobs = 64;
    #   supportedFeatures = [
    #     "big-parallel"
    #     "kvm"
    #     "nixos-test"
    #   ];
    # }
    {
      speedFactor = 0;
      hostName = "rose-builder-via-jumphost";
      protocol = "ssh";
      sshUser = "nix";
      sshKey = "/home/peter/.ssh/doctorBuilder"; # TODO use sops
      system = "x86_64-linux";
      maxJobs = 64;
      supportedFeatures = [
        "big-parallel"
        "kvm"
        "nixos-test"
      ];
    }
    {
      speedFactor = 0;
      hostName = "aarch64.nixos.community";
      maxJobs = 64;
      sshKey = "/home/peter/.ssh/doctorBuilder";
      sshUser = "pogobanane";
      # ssh-ed25519 public key:
      publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSU1VVHo1aTl1NUgyRkhOQW1aSnlvSmZJR3lVbS9IZkdoZnduYzE0MkwzZHMK";
      system = "aarch64-linux";
      supportedFeatures = [ "big-parallel" ];
    }
  ];
}
