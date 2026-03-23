{ inputs, modulesPath, flakepkgs, ... }:

{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    inputs.disko.nixosModules.disko
    ./disko-aenderer.nix
  ];

  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.efiInstallAsRemovable = true;
  # boot.loader.efi.canTouchEfiVariables = true;
  # boot.loader.refind.enable = true;
  # boot.loader.grub.devices = [ "/dev/disk/by-id/nvme-Micron_MTFDKBA512TGD-2BK15ABLT_253652D5E602" ];
  boot.loader.grub.devices = [ "nodev" ];
  boot.loader.grub.gfxmodeEfi = "1920x1200";
  boot.loader.grub.theme = flakepkgs.grub-theme;

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "usbhid" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.kernel.sysctl = {
    "kernel.sysrq" = 64; # permit term e, kill i, oom-kill f
  };

  # replace oomd and earlyoom with zswap:
  boot.kernelParams = [
    "zswap.enabled=1"
    "zswap.compressor=lz4"
    "zswap.max_pool_percent=20"
    "zswap.shrinker_enabled=1"
  ];
}
