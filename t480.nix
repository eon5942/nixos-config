# ThinkPad T480 (Intel 8th gen, iGPU only) — lean companion host to the
# NVIDIA workstation in configuration.nix. No dGPU, no gaming stack here;
# add packages as needed. Generate the real hardware-configuration.nix with
# `nixos-generate-config` once you're on the machine.
{ config, lib, pkgs, ... }:
{
  imports = [ ./t480-hardware-configuration.nix ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "t480";
  networking.networkmanager.enable = true;

  time.timeZone = "America/Los_Angeles";

  # Intel 8th-gen CPU microcode + redistributable firmware (iwlwifi etc.).
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  # Intel UHD 620 iGPU.
  hardware.graphics.enable = true;

  # ThinkPad BIOS / embedded-controller updates.
  services.fwupd.enable = true;

  # ThinkPad power management (dual battery).
  services.tlp.enable = true;

  # Ollama: local LLM server on localhost:11434. Unlike the NVIDIA workstation
  # (ollama-cuda + qwen3:14b), the T480 has no dGPU, so this runs CPU-only
  # (default `pkgs.ollama`) with a smaller model the 8th-gen i7 can drive.
  services.ollama = {
    enable = true;
    loadModels = [ "qwen3:4b" ];
  };

  # Same user as the main host; no agenix here, set a password on first login
  # with `passwd`.
  users.users.eon = {
    isNormalUser = true;
    description = "eon";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  system.stateVersion = "26.05";
}
