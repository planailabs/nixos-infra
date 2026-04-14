{ config, extendModules, lib, pkgs, diskoLib, ... }:

with lib;

{
  imports = [
    ./disko.nix
    ({
      _module.args.disks = [ "/dev/disk/by-id/ata-Samsung_SSD_850_PRO_512GB_S250NWAG831361V" "/dev/disk/by-id/ata-TOSHIBA_DT01ACA300_895D82NAS" "/dev/disk/by-id/ata-WDC_WD40EFAX-68JH4N1_WD-WX22D917F7AC" ];
    })
    ./hardware-configuration.nix
    ./network-configuration.nix
    ../modules/common.nix
  ];

  # Override installTest to provide VM disks large enough for the 3TB HDD partitions.
  # qcow2 images are sparse so this doesn't consume actual disk space.
  system.build.installTest = mkForce (diskoLib.testLib.makeDiskoTest {
    inherit extendModules pkgs;
    name = "${config.networking.hostName}-disko";
    disko-config = builtins.removeAttrs config [ "_module" ];
    testMode = "direct";
    bootCommands = config.disko.tests.bootCommands;
    efi = config.disko.tests.efi;
    enableOCR = config.disko.tests.enableOCR;
    extraSystemConfig = config.disko.tests.extraConfig;
    extraTestScript = config.disko.tests.extraChecks;
    extraInstallerConfig = {
      # Alphabetical order: hdd_a (3TB), hdd_b (3TB), ssd (512G) — in MiB
      virtualisation.emptyDiskImages = mkForce [ 3145728 3145728 524288 ];
    };
  });

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  networking.hostId = "4abb3901";

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

  networking.hostName = "omen";
  networking.firewall.allowedTCPPorts = [ 8443 ];
  networking.firewall.trustedInterfaces = [ "incusbr0" ];

  boot.kernel.sysctl."net.ipv4.conf.all.forwarding" = mkOverride 1 1;
  boot.kernel.sysctl."net.ipv6.conf.all.forwarding" = mkOverride 1 1;

  /* systemd.services.export-incus = {
    description = "Export Incus instances to Hetzner StorageBox";
    startAt = "daily";
    path = with pkgs; [ openssh sshfs fuse incus bash coreutils ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      bash ${../export-incus.sh} u570346@u570346.your-storagebox.de
    '';
  }; */

  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" "armv6l-linux" ];
}
