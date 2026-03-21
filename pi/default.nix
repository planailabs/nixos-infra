{ inputs, pkgs, ... }: {
  imports = [
    ./pi.nix
    ../modules/common.nix
    ./hardware-configuration.nix
  ];

  networking.firewall.logRefusedPackets = true;
  system.stateVersion = "26.11";

  virtualisation.incus.enable = true;
  virtualisation.incus.ui.enable = true;
  services.fwupd.enable = true;

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 23345;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  networking.hostName = "home-pi";
}
