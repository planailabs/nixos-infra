{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    inputs.common.nixosModules.hcloud_base
    ./nginx.nix
    ./uptime-kuma.nix
  ];

  # replace this address with the one assigned to your instance
  mgit.hcloud.auto-network = "2a01:4f8:c015:9181::2/64";

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

  networking.hostName = "uptime";

  security.acme.acceptTerms = true;

}
