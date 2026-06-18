{ config, inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/peira-relay.nix"
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
      listen_addr = "[::]:443";
      server_api_url = "https://api.peira.plan.ai";
      proxy_hostname = "relay.peira.plan.ai";
      proxy_url = "https://relay.peira.plan.ai";
      data_dir = "/var/lib/mac-mgmt-relay";
      cors_origins = [ "https://mgmt.peira.plan.ai" ];
      tls_cert_path = "${config.security.acme.certs."relay.peira.plan.ai".directory}/fullchain.pem";
      tls_key_path = "${config.security.acme.certs."relay.peira.plan.ai".directory}/key.pem";
    };
  };

  security.acme = {
    distributor-server = "https://acme.plan.ai";
    certs."relay.peira.plan.ai" = {
      domain = "relay.peira.plan.ai";
      group = "acme";
      webroot = "/var/lib/acme/acme-challenge";
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];

  systemd.services.mac-mgmt-relay = {
    wants = [ "acme-relay.peira.plan.ai.service" ];
    after = [ "acme-relay.peira.plan.ai.service" ];
    serviceConfig = {
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
      SupplementaryGroups = [ "acme" ];
      RestrictAddressFamilies = lib.mkForce [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
    };
  };

  networking.hostName = "peira-relay";
}
