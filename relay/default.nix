{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/relay.nix"
    ./nginx.nix
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

  services.mac-mgmt-relay = {
    enable = true;
    openFirewall = true;
    settings = {
      listen_addr = "127.0.0.1:7380";
      server_api_url = "https://api.plan.ai";
      proxy_hostname = "plan-ai-relay.com";
      proxy_url = "https://plan-ai-relay.com";
      data_dir = "/var/lib/mac-mgmt-relay";
      cors_origins = [ "https://mgmt.plan.ai" ];
    };
  };

  # libp2p QUIC enumerates interfaces via netlink
  systemd.services.mac-mgmt-relay.serviceConfig.RestrictAddressFamilies =
    lib.mkForce [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "relay";
}
