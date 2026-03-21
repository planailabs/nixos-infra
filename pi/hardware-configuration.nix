{ modulesPath, lib, ... }:

with lib;

{
  nixpkgs.hostPlatform = "aarch64-linux";
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64-new-kernel-no-zfs-installer.nix"
  ];
  networking.wireless.enable = mkForce false;
}
