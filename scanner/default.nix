{ inputs, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./network-configuration.nix
    ./nginx.nix
    ./rustnmap-api.nix
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

  # TLS certs come from the central ACME distributor on logos (the *.plan.ai
  # wildcard cert covers scanner.plan.ai). Token is set in private/scanner.nix.
  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "scanner";
}
