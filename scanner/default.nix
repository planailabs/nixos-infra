{ inputs, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./network-configuration.nix
    ../modules/common.nix
    "${inputs.self.private}/scanner.nix"
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  # Legacy BIOS VM — GRUB embeds into the EF02 partition from disko.nix.
  boot.loader.grub.enable = true;

  networking.hostName = "scanner";
}
