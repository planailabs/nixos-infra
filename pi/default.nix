{ inputs, pkgs, ... }: {
  imports = [
    ./pi.nix
    # ./wg.nix
    ./kiosk.nix
    ../modules/common.nix
    "${inputs.self.private}/pi.nix"
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
      port = 23346;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  swapDevices = [{
    device = "/swapfile";
    size = 5120; # 5 GiB
  }];

  networking.hostName = "plan-ai-pi";
}
