{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/obsidian.nix"
    ./nginx.nix
    ./services.nix
    ./home.nix
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

  security.acme.distributor-server = "https://acme.plan.ai";

  services.oauth2-proxy = {
    enable = true;
    provider = "google";
    email.domains = [ "plan.ai" ];
    reverseProxy = true;
    setXauthrequest = true;
    cookie.domain = ".plan.ai";
    extraConfig.whitelist-domain = ".plan.ai";
    nginx.domain = "wiki.plan.ai";
    nginx.virtualHosts."wiki.plan.ai" = { };
  };

  networking.hostName = "obsidian";
}
