{ lib, pkgs, ... }: {
  systemd.network = {
    enable = true;
    networks."40-eth0" = {
      matchConfig = {
        Name = "eth0";
      };
      gateway = [ "fe80::1" "65.108.140.193" ];
      networkConfig = {
        Address = [ "2a01:4f9:1a:90eb::2/128" "2a01:4f9:1a:2700::1/56" ];
      };
      addresses = [
        { Address = "65.108.140.241/26"; Peer = "65.108.140.193"; }
      ];
    };
  };

  networking = {
    dhcpcd.enable = false;

    nameservers = [
      ''213.133.98.98''
      ''213.133.99.99''
      ''213.133.100.100''
      ''2a01:4f8:0:1::add:1010''
      ''2a01:4f8:0:1::add:9999''
      ''2a01:4f8:0:1::add:9898''
    ];

    nftables.enable = true;

    firewall.logRefusedPackets = true;
  };
  networking.useDHCP = false;
  networking.useNetworkd = lib.mkForce true;
  services.udev.extraRules = ''ATTR{address}=="04:42:1a:23:db:9d", NAME="eth0"'';

  networking.firewall.allowedUDPPortRanges = [
    { from = 1120; to = 1129; }
  ];
  networking.firewall.allowedTCPPorts = [ 8787 ];

  systemd.services.ndp-proxy = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      Restart = "always";
      ExecStart = "${pkgs.callPackage ./ndp {}}/bin/ndp-proxy -i eth0 -m 56 -n 2a01:4f9:1a:2700::";
    };
  };
}
