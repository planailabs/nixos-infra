{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/postgres-upgrade.nix
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/harbor.nix"
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

  services.harbor-server = {
    enable = true;
    settings = {
      web.port = 7380;
      proxy = {
        domain = "harbor.plan.ai";
        # The old name: customer domains CNAME to it, so it keeps resolving
        # (a CNAME to harbor.plan.ai) and the app answers it with a 308.
        redirect_domains = [ "agency.plan.ai" ];
        acme_email = "admin@plan.ai";
      };
      local_hosting.dir = "/var/lib/harbor-server/web";
    };
  };

  services.harbor-proxy = {
    enable = true;
    openFirewall = true;
  };

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "harbor";
}
