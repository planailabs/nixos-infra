{ pkgs, ... }: {
  # The rustnmap REST API server (the `remote` scan backend). Upstream only
  # ships it as a crate example; the planailabs fork exposes it as the
  # rustnmap-api-server bin, built alongside the CLI in pkgs/rustnmap.nix. It
  # binds 127.0.0.1:8080 and logs freshly-generated API keys on each start —
  # grab them from `journalctl -u rustnmap-api`.
  systemd.services.rustnmap-api = {
    description = "RustNmap REST API server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.rustnmap}/bin/rustnmap-api-server";
      Restart = "on-failure";
      RestartSec = 5;
      DynamicUser = true;
      # Scan engines (SYN/UDP/etc.) need raw sockets; connect scans don't, but
      # grant the caps so every scan type the API exposes actually works.
      AmbientCapabilities = [ "CAP_NET_RAW" "CAP_NET_ADMIN" ];
      CapabilityBoundingSet = [ "CAP_NET_RAW" "CAP_NET_ADMIN" ];
      # Hardening — the server only needs loopback + outbound scan traffic.
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
