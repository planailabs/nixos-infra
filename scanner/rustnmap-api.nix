{ pkgs, ... }: {
  # The rustnmap REST API server (the `remote` scan backend). Upstream only
  # ships it as a crate example; the planailabs fork exposes it as the
  # rustnmap-api-server bin, built alongside the CLI in pkgs/rustnmap.nix.
  #
  # Listen address and API key come from the environment (see the fork's
  # server.rs). We bind loopback and let nginx terminate TLS for
  # scanner.plan.ai; the stable bearer token lives in /etc/rustnmap-api.env
  # (defined in private/scanner.nix).
  systemd.services.rustnmap-api = {
    description = "RustNmap REST API server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    environment.RUSTNMAP_API_LISTEN = "127.0.0.1:8080";
    serviceConfig = {
      ExecStart = "${pkgs.rustnmap}/bin/rustnmap-api-server";
      # RUSTNMAP_API_KEYS — the stable bearer token(s).
      EnvironmentFile = "/etc/rustnmap-api.env";
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
