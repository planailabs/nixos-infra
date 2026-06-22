{ inputs, config, extendModules, lib, pkgs, diskoLib, ... }:

with lib;

{
  imports = [
    ./disko.nix
    "${inputs.self.private}/omen.nix"
    ({
      _module.args.disks = [ "/dev/disk/by-id/ata-Samsung_SSD_850_PRO_512GB_S250NWAG831361V" "/dev/disk/by-id/ata-TOSHIBA_DT01ACA300_895D82NAS" "/dev/disk/by-id/ata-WDC_WD40EFAX-68JH4N1_WD-WX22D917F7AC" ];
    })
    ./hardware-configuration.nix
    ./network-configuration.nix
    ../modules/common.nix
    ./wg.nix
    ./zfs.nix
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
  networking.firewall.extraInputRules = ''
    ip6 saddr {
      2a01:4f8:242:ea00::/56,  # sodium ipv6 tunnel
      2a01:4f8:242:1ae1::/64,  # sodium vms
      2a01:4f9:1a:90eb::/64,   # atlas vms
      2a01:4f8:262:494f::/64,  # neon
    } tcp dport 11434 accept
    ip saddr 192.168.68.0/22 tcp dport 11434 accept  # wifi
    ip6 saddr 201:39a5:2fa6:ffb0:41e8:475c:e129:f30d tcp dport 11434 accept  # mkg-laptop
  '';

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

  services.mac-mgmt = {
    enable = true;
    serverUrl = "https://api.plan.ai";
    version = "0.1.5";
    environmentFile = "/etc/mac-mgmt.env";
    settings = {
      daemon.log_level = "info";
    };
  };

  services.nix-driver-sync = {
    enable = true;
    projects = [ "default" "mmr" ];
    gpuPci = "0000:65:00.0";
  };

  boot.binfmt.emulatedSystems = [ "aarch64-linux" "armv7l-linux" "armv6l-linux" ];

  hardware.nvidia.package = config.boot.kernelPackages.nvidiaPackages.stable;
  hardware.nvidia.open = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.graphics.enable = true;

  # ref https://www.howtoforge.com/ipp_based_print_server_cups
  services.printing = {
    enable = true;
    startWhenNeeded = false;
    allowFrom = [ "@LOCAL" ];
    browsing = true;
    defaultShared = true;
    openFirewall = true;
    listenAddresses = [ "*:631" ];
    # disable auth
    extraConf = ''
      AuthType Basic
      AuthClass System
      BrowseLocalProtocols dnssd
      DefaultPaperSize A4
      ReadyPaperSizes A4
    '';
  };

  services.avahi = {
    enable = true;
    publish = {
      enable = true;
      userServices = true;
    };
  };

  boot.kernelParams = [ "swapaccount=1"  "reboot=efi" ];

  systemd.services.ztrim = {
    startAt = "weekly";
    script = ''
      /run/current-system/sw/bin/zpool trim omen
    '';
  };

  systemd.services.local-net = {
    enable = true;
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    script = ''
      bash ${./hop-switch.sh}
    '';
    path = with pkgs; [ bash inetutils iproute2 ];
    serviceConfig = {
      Restart = "always";
      RestartSec = 5;
    };
  };

  services.fwupd.enable = true;

  environment.systemPackages = with pkgs; [
    nvtopPackages.nvidia
  ];
}
