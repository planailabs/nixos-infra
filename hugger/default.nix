{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/hugger.nix"
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

  services.hugger = {
    enable = true;
    host = "127.0.0.1";
    port = 7860;
    # Served over TLS by nginx (see ./nginx.nix), so send HSTS and pin the host.
    httpsOnly = true;
    allowedHosts = [ "hugger.plan.ai" ];
    # HUGGER_PASSWORD / HF_TOKEN live outside the repo.
    environmentFile = "/etc/hugger.env";
  };

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "hugger";
}
