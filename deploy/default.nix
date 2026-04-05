{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
  ];

  systemd.network = {
    networks."40-public0" = {
      matchConfig = {
        Name = "public0";
      };
      gateway = [ "65.108.140.193" ];
      addresses = [
        { addressConfig = { Address = "65.108.140.227/26"; Peer = "65.108.140.193"; }; }
      ];
    };
  };

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14455;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  virtualisation.docker.enable = true;
  virtualisation.docker.liveRestore = false;
  virtualisation.incus.enable = true;

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
  networking.hostName = "deploy";

  nix = {
    gc.automatic = mkForce false;

    settings = {
      # sandbox = true;
      trusted-users = [ "root" "@builder" ];
      # Keep the build dependencies of derivations arround.
      gc-keep-outputs = true;
      gc-keep-derivations = true;
      env-keep-derivations = true;
      # Automatic gc during build. Keep at least 12 gig free, gc if below 6 gig.
      min-free = toString (6 * 1024 * 1024 * 1024);
      max-free = toString (12 * 1024 * 1024 * 1024);
    };
  };
}

