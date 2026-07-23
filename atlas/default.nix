{ lib, pkgs, ... }:

with lib;

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
  virtualisation.incus.ui.enable = true;

  networking.hostName = "atlas";
  networking.firewall.allowedTCPPorts = [ 8443 ];
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = mkOverride 1 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = mkOverride 1 1;

  systemd.services.export-incus = {
    description = "Export Incus instances to Hetzner StorageBox";
    startAt = "daily";
    path = with pkgs; [ openssh sshfs fuse incus bash coreutils ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      bash ${../export-incus.sh} u570346@u570346.your-storagebox.de
    '';
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" "armv6l-linux" ];

  boot.kernelParams = [ "swapaccount=1" ];

  systemd.services.ztrim = {
    startAt = "weekly";
    script = ''
      /run/current-system/sw/bin/zpool trim rtorrent
    '';
  };

  services.fwupd.enable = true;

  # wg-vpng node: a dumb WireGuard switch the wg-vpng server (logos) drives over
  # HTTP to create interfaces here. Provision the bearer key out-of-band at
  # /etc/wg-vpng-node.key (matching the key set on the interface in the admin UI).
  services.wg-vpng-node = {
    enable = true;
    openFirewall = true;
    settings.backend = "self-managed";
    apiKeyFile = "/etc/wg-vpng-node.key";
  };
}
