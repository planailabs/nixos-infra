{ lib, ... }: {
  systemd.network = {
    enable = true;
    networks."40-eth0" = {
      matchConfig = {
        Name = "eth0";
      };
      gateway = [ "fe80::1" "176.9.148.193" ];
      networkConfig = {
        Address = [ "2a01:4f8:160:31c4::2/128" ];
      };
      addresses = [
        { Address = "176.9.148.211/27"; Peer = "176.9.148.193"; }
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
  services.udev.extraRules = ''ATTR{address}=="bc:fc:e7:ca:97:d1", NAME="eth0"'';
}

