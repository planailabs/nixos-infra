{
  imports = [
    ./disko.nix
    ({
      _module.args.disks = [ "/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00B00_S675NF0R800054_1" "/dev/disk/by-id/nvme-SAMSUNG_MZVL2512HCJQ-00B00_S675NF0R800058_1" ];
    })
    ./hardware-configuration.nix
    ./network-configuration.nix
    ../modules/common.nix
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostId = "c248e870";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  virtualisation.incus.enable = true;
  virtualisation.incus.softDaemonRestart = true;
}
