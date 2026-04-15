{ pkgs, ... }: {
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.forwarding" = true;
    "net.ipv6.conf.default.forwarding" = true;
    "net.ipv4.conf.all.forwarding" = true;
    "net.ipv4.conf.default.forwarding" = true;

    # allow IPv6 addrs to directly go out
    "net.ipv6.conf.all.proxy_ndp" = "1";
  };

  networking.firewall.trustedInterfaces = [ "wg0" "wlan0" ];
  # networking.firewall.filterForward = true;
  networking.firewall.extraForwardRules = ''
    iifname { "wg0", "wlan0" } oifname { "wg0", "wlan0" } accept
  '';

  networking.wireguard.enable = true;
  networking.wireguard.useNetworkd = false;

  networking.wireguard.interfaces = {
    # "wg0" is the network interface name. You can name the interface arbitrarily.
    wg0 = {
      # Determines the IP address and subnet of the server's end of the tunnel interface.
      ips = [ "10.44.0.4/32" "2a01:4f8:242:ea52::2/128" ]; # "2a01:4f8:242:ea44::1/62" ];

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
