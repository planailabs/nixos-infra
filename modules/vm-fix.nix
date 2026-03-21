{ config, lib, pkgs, ... }:

with lib;

{
  nixpkgs.hostPlatform = mkIf (config.virtualisation ? fileSystems) (mkForce "x86_64-linux");
  networking.useDHCP = mkIf (config.virtualisation ? fileSystems) (mkForce true);
  # for rpi
  boot.kernelPackages = mkIf (config.virtualisation ? fileSystems) (mkForce pkgs.linuxPackages);
}

