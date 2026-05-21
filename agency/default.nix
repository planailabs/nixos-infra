{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/agency.nix"
  ];

  systemd.network = {
    networks."40-public0" = {
      matchConfig = {
        Name = "public0";
      };
      gateway = [ "65.108.140.193" ];
      addresses = [
        { Address = "65.108.140.205/26"; Peer = "65.108.140.193"; }
      ];
    };
  };

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  services.web-agency-server = {
    enable = true;
    settings = {
      web.port = 7380;
      proxy = {
        agency_domain = "agency.plan.ai";
        acme_email = "admin@plan.ai";
      };
    };
  };

  services.web-agency-proxy = {
    enable = true;
    openFirewall = true;
  };

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "agency";
}
