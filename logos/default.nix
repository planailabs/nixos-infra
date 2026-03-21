{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/logos.nix"
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

  services.acme-distributor = {
    enable = true;
  };

#  security.acme.distributor-server = "https://acme.plan.ai";
  security.acme.distributor-server = "http://localhost:3444";

  networking.hostName = "logos";
}
