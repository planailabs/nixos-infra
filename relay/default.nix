{ config, inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/relay.nix"
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  systemd.network = {
    networks."40-public0" = {
      matchConfig = {
        Name = "public0";
      };
      gateway = [ "65.108.140.193" ];
      addresses = [
        { Address = "65.108.140.247/26"; Peer = "65.108.140.193"; }
      ];
    };
  };

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
      server_api_url = "https://api.plan.ai";
      proxy_hostname = "plan-ai-relay.com";
      proxy_url = "https://plan-ai-relay.com";
      data_dir = "/var/lib/mac-mgmt-relay";
      cors_origins = [ "https://mgmt.plan.ai" ];
      tls_cert_path = "${config.security.acme.certs."plan-ai-relay.com".directory}/fullchain.pem";
      tls_key_path = "${config.security.acme.certs."plan-ai-relay.com".directory}/key.pem";
    };
  };

  security.acme = {
    distributor-server = "https://acme.plan.ai";
    certs."plan-ai-relay.com" = {
      domain = "plan-ai-relay.com";
      extraDomainNames = [
        "*.plan-ai-relay.com"
        "relay.plan.ai"
      ];
      group = "acme";
      webroot = "/var/lib/acme/acme-challenge";
    };
  };

  networking.firewall.allowedTCPPorts = [ 443 ];

  systemd.services.mac-mgmt-relay = {
    wants = [ "acme-plan-ai-relay.com.service" ];
    after = [ "acme-plan-ai-relay.com.service" ];
    serviceConfig = {
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = lib.mkForce [ "CAP_NET_BIND_SERVICE" ];
      SupplementaryGroups = [ "acme" ];
      RestrictAddressFamilies = lib.mkForce [ "AF_INET" "AF_INET6" "AF_UNIX" "AF_NETLINK" ];
    };
  };

  networking.hostName = "relay";
}
