{ pkgs, ... }: {
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.forwarding" = true;
    "net.ipv6.conf.default.forwarding" = true;
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv4.conf.default.forwarding" = true;

    # allow IPv6 addrs to directly go out
    "net.ipv6.conf.all.proxy_ndp" = "1";
  };

  services.kea.dhcp6 = {
    enable = true;
    settings = {
      interfaces-config = {
        interfaces = [
          "end0"
        ];
      };
      lease-database = {
        name = "/var/lib/kea/dhcp6.leases";
        persist = true;
        type = "memfile";
      };
      preferred-lifetime = 3600;
      valid-lifetime = 7200;
      rebind-timer = 2000;
      renew-timer = 1000;
      subnet6 = [
        {
          id = 1;
          rapid-commit = true;
          pools = [
            { pool = "2a01:4f8:242:ea46::2 - 2a01:4f8:242:ea46:ffff:ffff:ffff:ffff"; }
          ];
          subnet = "2a01:4f8:242:ea48::/62";
          interface = "end0";
          # subnet = "::/0";
        }
      ];
    };
  };

  networking.firewall.trustedInterfaces = [ "wg0" "end0" ];
  # networking.firewall.filterForward = true;
  networking.firewall.extraForwardRules = ''
    iifname { "wg0", "end0" } oifname { "wg0", "end0" } accept
  '';
  networking.firewall.extraInputRules = ''
    meta nfproto ipv4 udp sport . udp dport { 68 . 67, 67 . 68 } accept comment "DHCPv4 client/server"
    meta nfproto ipv4 udp dport 53 accept comment "dns"
    ip6 nexthdr icmpv6 accept
    meta nfproto ipv6 udp dport { 546, 547 } accept
    meta nfproto ipv6 udp sport { 546, 547 } accept
  '';

  services.radvd = {
    enable = true;
    config = ''
    interface wlan0
    {
         AdvSendAdvert on;
         AdvDefaultLifetime 1800;
         AdvDefaultPreference high;
         prefix 2a01:4f8:242:ea49::/64 {
             AdvOnLink on;
             AdvRouterAddr off;
             AdvAutonomous on;
         };
    };
    '';
  };

  networking.wireguard.enable = true;
  networking.wireguard.useNetworkd = false;

  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = [ "10.44.0.3/32" "2a01:4f8:242:ea48::2/128" ]; # "2a01:4f8:242:ea44::1/62" ];

      # The port that WireGuard listens to. Must be accessible by the client.
      listenPort = 1122;
      mtu = 1300;
      metric = 5;

      # mtu = 1400;

      #
      # Note: The private key can also be included inline via the privateKey option,
      # but this makes the private key world-readable; thus, using privateKeyFile is
      # recommended.
      privateKeyFile = "/var/wg-priv";

      peers = [
        {
          # server
          publicKey = "1wyhHlaR3bmKW68fBS8ibC8pu0/VZrIvIUkadB97ETI=";
          allowedIPs = [ "10.44.0.0/24" "::/0" ];
          endpoint = "168.119.72.237:1122"; # sodium
        }
      ];
    };
  };

  /*systemd.services.ipv6-route = {
    startAt = "hourly";
    serviceConfig = {
      Type = "oneshot";
    };
    path = with pkgs; [ iproute2 ];
    script = ''
      ip -6 r r 2a01:4f8:242:ea44::/62 via fe80::3e37:12ff:fe1e:a7fc dev end0 metric 10
      ip -6 r r default dev wg0
    '';
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "sys-subsystem-net-devices-end0.device" ];
    requires = [ "sys-subsystem-net-devices-end0.device" ];
  };*/

  systemd.services.kea-dhcp6-server = {
    after = [ "network-online.target" "sys-subsystem-net-devices-end0.device" ];
    requires = [ "sys-subsystem-net-devices-end0.device" ];
  };

  networking.nftables.tables.filter = {
    family = "inet";
    content = ''
      chain forward {
        type filter hook forward priority 0; policy accept;
        oifname "wg0" counter tcp flags syn tcp option maxseg size set 1200
      }
    '';
  };
}
