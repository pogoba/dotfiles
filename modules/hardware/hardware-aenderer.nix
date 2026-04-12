{ lib, config, inputs, modulesPath, flakepkgs, ... }:

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
  boot.loader.grub.gfxpayloadEfi = "keep";
  boot.loader.grub.theme = flakepkgs.grub-theme;
  boot.loader.grub.splashImage = null;

  services.fprintd.enable = true;

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "usb_storage" "usbhid" "thunderbolt" ];
  boot.initrd.kernelModules = [ "dm-snapshot" ];
  boot.kernelModules = [ "kvm-amd" ];
  boot.extraModulePackages = [ ];

  # swap ctrl and fn keys (see also evtest)
  # needs sudo udevadm trigger --subsystem-match=input and reboot after nixos switch
  services.udev.extraHwdb = ''
    evdev:input:b0011v0001p0001*
      KEYBOARD_KEY_3a=esc
  '';



  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.amd.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;


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
