# prometheus-mcp: Prometheus as an MCP server (Streamable HTTP) for the chat's
# assistants, at https://prometheus-mcp.plan.ai/mcp. nginx admits only the
# bearer token in private/logos.nix (and drops it before proxying); the server
# itself queries the local Prometheus.
{ pkgs, ... }: {
  systemd.services.prometheus-mcp = {
    description = "Prometheus MCP server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "prometheus.service" ];
    serviceConfig = {
      ExecStart = "${pkgs.prometheus-mcp}/bin/prometheus-mcp-server --mcp.transport=http --web.listen-address=127.0.0.1:8096 --prometheus.url=http://127.0.0.1:9090";
      DynamicUser = true;
      Restart = "on-failure";
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
