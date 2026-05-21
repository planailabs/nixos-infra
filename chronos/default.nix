{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/chronos.nix"
  ];

  systemd.network = {
    networks."40-public0" = {
      matchConfig = {
        Name = "public0";
      };
      gateway = [ "65.108.140.193" ];
      addresses = [
        { Address = "65.108.140.232/26"; Peer = "65.108.140.193"; }
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

  virtualisation.docker.enable = true;
  virtualisation.docker.liveRestore = false;

  systemd.services.docker-iptables-fix = {
    path = with pkgs; [ iptables-nftables-compat ];
    requires = [ "docker.service" ];
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      for i in $(seq 1 100); do
        sleep 2s
        iptables -P FORWARD ACCEPT
        ip6tables -P FORWARD ACCEPT
      done
    '';
  };
  networking.hostName = "chronos";

  security.acme.distributor-server = "https://acme.plan.ai";

  # Gitlab port
  services.openssh.ports = [ 22222 ];

  environment.variables."GITLAB_HOME" = "/srv/gitlab";

  boot.kernel.sysctl = {
    "kernel.keys.maxkeys" = 20000;
    "kernel.keys.maxbytes" = 2000000;
  };

  networking.firewall.allowedTCPPorts = [
    80 443 22
  ];
}
