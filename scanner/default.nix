{ inputs, lib, pkgs, ... }:

with lib;

{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ./network-configuration.nix
    ./nginx.nix
    inputs.securitybird.nixosModules.rustnmap-api
    ../modules/common.nix
    "${inputs.self.private}/scanner.nix"
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  # The rustnmap REST API server (the `remote` scan backend), from the
  # securitybird flake. nginx terminates TLS for scanner.plan.ai in front of
  # it (see nginx.nix); the stable bearer token lives in /etc/rustnmap-api.env
  # (defined in private/scanner.nix). We build the package once via the
  # overlay in modules/common.nix so the server and the CLI in
  # environment.systemPackages are the same derivation.
  services.rustnmap-api = {
    enable = true;
    package = pkgs.rustnmap;
    listen = "127.0.0.1:8080";
    apiKeysFile = "/etc/rustnmap-api.env";
    # SYN/UDP/stealth scans need raw sockets; grant CAP_NET_RAW/CAP_NET_ADMIN.
    rawSocketCapability = true;
  };

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
