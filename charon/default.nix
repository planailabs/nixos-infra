{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    inputs.common.nixosModules.hcloud_base
    "${inputs.self.private}/charon.nix"
    ./storagebox.nix
    ./transmission.nix
    ./vpn.nix
  ];

  # Transmission runs confined to a network namespace whose only route is a
  # WireGuard tunnel to Mullvad, so peer traffic can never use charon's own
  # 49.12.9.126 / 2a01:4f8:c013:6665::2. de-fra-wg-003 is Mullvad-owned and
  # measured 5.3ms from Falkenstein (Berlin, despite being nearer, is 23ms).
  charon.vpn = {
    enable = true;
    # Assigned by Mullvad to this host's public key
    # (HTX3OxclHdjfVEJYlXw0UuSbZWD/2x3t/rvcpMssNAY=, private half in
    # /var/wg-priv).
    addresses = [ "10.75.177.68/32" "fc00:bbbb:bbbb:bb01::c:b143/128" ];
    peer = {
      publicKey = "vVQKs2TeTbdAvl3sH16UWLSESncXAj0oBaNuFIUkLVk=";
      # The literal IP rather than de-fra-wg-003.relays.mullvad.net, so
      # bringing the tunnel up at boot doesn't depend on DNS being ready.
      endpoint = "185.209.196.73:51820";
    };
  };

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
