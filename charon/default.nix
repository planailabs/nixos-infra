{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    inputs.common.nixosModules.hcloud_base
    "${inputs.self.private}/charon.nix"
    ./storagebox.nix
    ./transmission.nix
  ];

  # The /64 Hetzner Cloud assigned this instance. hcloud_base only configures
  # networkd (and the fe80::1 default route) when this is set; without it the
  # host is IPv4-only.
  mgit.hcloud.auto-network = "2a01:4f8:c013:6665::2/64";

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  networking.hostName = "charon";
}
