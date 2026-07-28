{ lib, ... }: {
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
  networking.useNetworkd = lib.mkForce false;
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.powersave = false;
  networking.networkmanager.wifi.backend = "iwd";
#  services.udev.extraRules = ''ATTR{address}=="04:42:1a:23:db:9d", NAME="eth0"'';
}

