{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/chronos.nix"
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

  # Gitlab port
  services.openssh.ports = [ 22222 ];

  virtualisation.docker.enable = true;

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

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "chronos";

  environment.variables."GITLAB_HOME" = "/srv/gitlab";

  boot.kernel.sysctl = {
    "kernel.keys.maxkeys" = 20000;
    "kernel.keys.maxbytes" = 2000000;
  };
}
