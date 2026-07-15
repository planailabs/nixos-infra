{ lib, ... }: {
  # The provider hands out the /32 IPv4 (150.40.117.230) via DHCP with an
  # on-link gateway, and IPv6 (2a0e:bfc7:1400:2b35::1) via router
  # advertisements — so unlike the Hetzner hosts we stay on DHCP here.
  systemd.network = {
    enable = true;
    networks."40-eth0" = {
      matchConfig = {
        Name = "eth0";
      };
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = true;
      };
    };
  };

  networking = {
    dhcpcd.enable = false;

    nftables.enable = true;

    firewall.logRefusedPackets = true;
  };
  networking.useDHCP = false;
  networking.useNetworkd = lib.mkForce true;
  services.udev.extraRules = ''ATTR{address}=="3a:8d:20:f3:a0:02", NAME="eth0"'';
}
