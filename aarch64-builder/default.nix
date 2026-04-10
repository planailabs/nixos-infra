{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/hcloud-arm/configuration.nix
  ];

  mgit.hcloud.auto-network = "2a01:4f9:c014:9aba::1/64";

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "aarch64-linux";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14455;
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
  networking.hostName = "aarch64-builder";

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAC1D5tV2Tjx2G76VT/hPxMx6H+o7nlxm6nMhobpZq8M root@nixos"
  ];

  nix = {
    gc.automatic = mkForce false;

    settings = {
      trusted-users = [ "root" "@builder" ];
      gc-keep-outputs = true;
      gc-keep-derivations = true;
      env-keep-derivations = true;
      min-free = toString (6 * 1024 * 1024 * 1024);
      max-free = toString (12 * 1024 * 1024 * 1024);
    };
  };
}
