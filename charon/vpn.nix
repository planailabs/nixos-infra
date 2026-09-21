{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.charon.vpn;

  netnsService = "netns-${cfg.namespace}";
  wgService = "wg-${cfg.interface}";
  nsPath = "/run/netns/${cfg.namespace}";

  isV6 = a: hasInfix ":" a;
  hasV4 = any (a: !isV6 a) cfg.addresses;
  hasV6 = any isV6 cfg.addresses;
in
{
  options.charon.vpn = {
    enable = mkEnableOption "confining transmission to a Mullvad WireGuard network namespace";

    namespace = mkOption {
      type = types.str;
      default = "mullvad";
      description = "Name of the network namespace transmission is confined to.";
    };

    interface = mkOption {
      type = types.str;
      default = "wg-mullvad";
      description = "Name of the WireGuard interface moved into the namespace.";
    };

    privateKeyFile = mkOption {
      type = types.path;
      default = "/var/wg-priv";
      description = ''
        This host's WireGuard private key, kept out of the nix store -- same
        convention as pi/wg.nix and odysseus/wg.nix. Generated with `wg genkey`;
        the matching public key has to be registered with Mullvad.
      '';
    };

    addresses = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "10.66.12.34/32" "fc00:bbbb:bbbb:bb01::1:1234/128" ];
      description = ''
        Tunnel addresses Mullvad assigned to this key. Mullvad hands out a /32
        and a /128, so these are host routes, not subnets.
      '';
    };

    dns = mkOption {
      type = types.listOf types.str;
      default = [ "10.64.0.1" ];
      description = ''
        Resolvers for processes inside the namespace. The default is Mullvad's
        in-tunnel resolver, which is reachable *only* over the tunnel -- so name
        resolution fails closed along with everything else if the tunnel drops,
        rather than falling back to the host's resolver and leaking queries.
      '';
    };

    mtu = mkOption {
      type = types.int;
      default = 1420;
      description = "Tunnel MTU. 1420 is what Mullvad recommends for WireGuard.";
    };

    peer = {
      publicKey = mkOption {
        type = types.str;
        default = "";
        description = "Public key of the Mullvad relay to connect to.";
      };

      endpoint = mkOption {
        type = types.str;
        default = "";
        example = "de-fra-wg-001.relays.mullvad.net:51820";
        description = "host:port of the Mullvad relay.";
      };
    };

    rpcPort = mkOption {
      type = types.port;
      default = 9091;
      description = ''
        Port transmission's RPC listens on inside the namespace, and the port
        proxied into it from the root namespace.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.addresses != [ ];
        message = "charon.vpn.addresses must list the tunnel addresses Mullvad assigned to this key.";
      }
      {
        assertion = cfg.peer.publicKey != "" && cfg.peer.endpoint != "";
        message = "charon.vpn.peer.publicKey and charon.vpn.peer.endpoint must both be set.";
      }
    ];

    boot.kernelModules = [ "wireguard" ];

    environment.systemPackages = [ pkgs.wireguard-tools ];

    # `ip netns exec` bind-mounts this over /etc/resolv.conf. systemd's
    # NetworkNamespacePath= does *not* do that, so the transmission unit below
    # bind-mounts it explicitly as well.
    environment.etc."netns/${cfg.namespace}/resolv.conf".text =
      concatMapStrings (s: "nameserver ${s}\n") cfg.dns;

    systemd.services.${netnsService} = {
      description = "Network namespace ${cfg.namespace}";
      wantedBy = [ "multi-user.target" ];
      before = [ "${wgService}.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        # `ip netns add` bind-mounts the namespace under /run/netns, and that
        # has to stay visible to every other unit -- so this one gets no mount
        # sandboxing.
        PrivateMounts = false;
        ExecStart = pkgs.writeShellScript "${netnsService}-up" ''
          set -eu
          if ! ${pkgs.iproute2}/bin/ip netns list | ${pkgs.gnugrep}/bin/grep -qx '${cfg.namespace}'; then
            ${pkgs.iproute2}/bin/ip netns add ${cfg.namespace}
          fi
          ${pkgs.iproute2}/bin/ip -n ${cfg.namespace} link set lo up
        '';
        ExecStop = "${pkgs.iproute2}/bin/ip netns delete ${cfg.namespace}";
      };
    };

    systemd.services.${wgService} = {
      description = "Mullvad WireGuard tunnel inside netns ${cfg.namespace}";
      wantedBy = [ "multi-user.target" ];
      requires = [ "${netnsService}.service" ];
      after = [ "${netnsService}.service" "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.iproute2 pkgs.wireguard-tools ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "${wgService}-up" ''
          set -eu

          # The device is created in the *root* namespace on purpose. A
          # WireGuard interface keeps sending its encrypted UDP from the
          # namespace it was created in, so after the plaintext side is moved
          # into ${cfg.namespace} the tunnel still dials out over the host's
          # normal uplink -- while nothing inside the namespace can reach the
          # uplink directly. This is the netns trick documented in wg-quick(8).
          ip link add ${cfg.interface} type wireguard
          ip link set ${cfg.interface} netns ${cfg.namespace}

          ip -n ${cfg.namespace} link set ${cfg.interface} mtu ${toString cfg.mtu}
          ${concatMapStringsSep "\n          "
            (a: "ip -n ${cfg.namespace} address add ${a} dev ${cfg.interface}")
            cfg.addresses}

          # Set the key and peer from inside the namespace, where the device
          # now lives. Read straight from ${cfg.privateKeyFile} so the key never
          # reaches the nix store or the process table.
          ip netns exec ${cfg.namespace} wg set ${cfg.interface} \
            private-key ${cfg.privateKeyFile} \
            peer ${cfg.peer.publicKey} \
              endpoint ${cfg.peer.endpoint} \
              allowed-ips 0.0.0.0/0,::/0 \
              persistent-keepalive 25

          ip -n ${cfg.namespace} link set ${cfg.interface} up

          # The only routes in the namespace. There is no veth and no other
          # interface, so if the tunnel is down nothing gets out at all -- the
          # kill switch is the absence of an alternative, not a firewall rule.
          ${optionalString hasV4 "ip -n ${cfg.namespace} -4 route add default dev ${cfg.interface}"}
          ${optionalString hasV6 "ip -n ${cfg.namespace} -6 route add default dev ${cfg.interface}"}
        '';
        ExecStop = pkgs.writeShellScript "${wgService}-down" ''
          ${pkgs.iproute2}/bin/ip -n ${cfg.namespace} link del ${cfg.interface} || true
        '';
      };
    };

    # Transmission itself runs with the namespace as its only network. Its peer
    # traffic therefore cannot leave except through the tunnel.
    systemd.services.transmission = {
      requires = [ "${wgService}.service" ];
      after = [ "${wgService}.service" ];
      serviceConfig = {
        NetworkNamespacePath = nsPath;
        # Appended after the module's own BindReadOnlyPaths=/etc, so it lands
        # on top of the /etc it mounts into the unit's RootDirectory=.
        BindReadOnlyPaths = [
          "/etc/netns/${cfg.namespace}/resolv.conf:/etc/resolv.conf"
        ];
      };
    };

    # The web UI has to stay reachable from the yggdrasil mesh, but the
    # namespace deliberately has no veth back to the host. systemd creates this
    # listening socket in the root namespace and hands it to the proxy as an
    # fd; the proxy process itself joins the namespace, so it can connect to
    # transmission on the namespace's loopback. No forwarding, no NAT, and no
    # second way out of the namespace.
    systemd.sockets.transmission-rpc-proxy = {
      description = "Transmission RPC socket (root netns)";
      wantedBy = [ "sockets.target" ];
      socketConfig = {
        ListenStream = "[::]:${toString cfg.rpcPort}";
        BindIPv6Only = "both";
      };
    };

    systemd.services.transmission-rpc-proxy = {
      description = "Proxy transmission's RPC into netns ${cfg.namespace}";
      requires = [ "transmission.service" "transmission-rpc-proxy.socket" ];
      after = [ "transmission.service" "transmission-rpc-proxy.socket" ];
      serviceConfig = {
        NetworkNamespacePath = nsPath;
        ExecStart = "${pkgs.systemd}/lib/systemd/systemd-socket-proxyd --exit-idle-time=5min 127.0.0.1:${toString cfg.rpcPort}";
        User = "nobody";
        Group = "nogroup";
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        NoNewPrivileges = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" "AF_UNIX" ];
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
      };
    };
  };
}
