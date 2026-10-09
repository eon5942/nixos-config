# ThinkPad T480 hardware. The kernel module list below is the stock T480 set
# (Realtek SD reader `rtsx_pci`, NVMe, etc.). Replace this whole file with the
# output of `nixos-generate-config` run on the T480 — that captures the real
# disk UUIDs / fileSystems layout, which we can't know ahead of time.
{ config, lib, pkgs, ... }:
{
  boot.initrd.availableKernelModules = [ "xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];
}
