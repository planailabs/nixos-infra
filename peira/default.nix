{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/peira.nix"
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

  services.xzar-server = {
    enable = true;
  };

  services.mac-mgmt-server = {
    enable = true;
  };

  services.mac-mgmt-relay = {
    enable = true;
    openFirewall = true;
    settings = {
      listen_addr = "127.0.0.1:7380";
      server_api_url = "https://api.peira.plan.ai";
      proxy_hostname = "relay.peira.plan.ai";
      proxy_url = "https://relay.peira.plan.ai";
      data_dir = "/var/lib/mac-mgmt-relay";
      cors_origins = [ "https://mgmt.peira.plan.ai" ];
    };
  };

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "peira";
}
