{ inputs, lib, pkgs, ... }: with lib; {
  imports = [
    ../modules/common.nix
    ../modules/container.nix
    "${inputs.self.private}/redream.nix"
    ./nginx.nix
  ];

  system.stateVersion = "26.11";

  nixpkgs.hostPlatform = "x86_64-linux";

  mkg.mod = {
    yggdrasil = {
      enable = true;
      port = 14466;
      peers = [ "tcp://ygg.mkg20001.io:80" "tls://ygg.mkg20001.io:443" ];
    };
  };

  services.redream = {
    enable = true;
    # Secrets (${VAR} below) live in /etc/redream.env, see private/redream.nix.
    environmentFile = "/etc/redream.env";
    settings = {
      listen = "127.0.0.1:8088";
      auth = {
        external_url = "https://redream.plan.ai";
        cookie_secret = "\${COOKIE_SECRET}";
        providers = [{
          slug = "google";
          name = "Google";
          issuer = "https://accounts.google.com";
          client_id = "\${GOOGLE_CLIENT_ID}";
          client_secret = "\${GOOGLE_CLIENT_SECRET}";
          allowed_domains = [ "plan.ai" ];
        }];
      };
      hosts = [
        { id = "main"; name = "Main server"; address = "10.88.0.112"; username = "root"; password = "\${IDRAC_PASSWORD}"; }
        { id = "build"; name = "Build server"; address = "10.88.0.113"; username = "root"; password = "\${IDRAC_PASSWORD}"; }
      ];
    };
  };

  # The iDRACs sit on 10.88.0.0/24 behind the MikroTik at router.oliver-koss.at
  # (WireGuard vpn0, peer "redream"). Private key: private/redream.nix.
  systemd.network.netdevs."50-idrac0" = {
    netdevConfig = { Kind = "wireguard"; Name = "idrac0"; MTUBytes = "1380"; };
    wireguardConfig.PrivateKeyFile = "/etc/wireguard/idrac0.key";
    wireguardPeers = [{
      PublicKey = "HY15g1tirhfWXi7P0LVpuDRBPUfkf7QLYQkBWehIXRc=";
      Endpoint = "router.oliver-koss.at:3333";
      AllowedIPs = [ "10.88.0.0/24" "10.89.0.0/24" ];
      PersistentKeepalive = 25;
    }];
  };
  systemd.network.networks."50-idrac0" = {
    matchConfig.Name = "idrac0";
    address = [ "10.89.0.4/32" ];
    routes = [ { Destination = "10.88.0.0/24"; } { Destination = "10.89.0.0/24"; } ];
  };

  security.acme.distributor-server = "https://acme.plan.ai";

  networking.hostName = "redream";
}
