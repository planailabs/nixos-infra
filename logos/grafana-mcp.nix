# Grafana's MCP server (github.com/grafana/mcp-grafana), run with uvx as its
# docs do, pinned to one release, as Streamable HTTP on 127.0.0.1:8097 for the
# chat's assistants at https://grafana-mcp.plan.ai/mcp. nginx admits only the
# bearer token in private/logos.nix; GRAFANA_SERVICE_ACCOUNT_TOKEN (service
# account "mcp-grafana") comes from /etc/grafana-mcp.env, also private.
{ pkgs, ... }: {
  systemd.services.grafana-mcp = {
    description = "Grafana MCP server";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "grafana.service" ];
    wants = [ "network-online.target" ];
    environment = {
      GRAFANA_URL = "http://127.0.0.1:3434";
      # The wheel carries a static Go binary; uv only needs an interpreter, and
      # its own downloaded Pythons don't run on NixOS.
      UV_PYTHON = "${pkgs.python3}/bin/python3";
      UV_PYTHON_DOWNLOADS = "never";
      UV_CACHE_DIR = "/var/cache/grafana-mcp";
      HOME = "/var/lib/grafana-mcp";
    };
    serviceConfig = {
      ExecStart = "${pkgs.uv}/bin/uvx mcp-grafana@2.2.0 --transport streamable-http --address 127.0.0.1:8097";
      EnvironmentFile = "/etc/grafana-mcp.env";
      DynamicUser = true;
      StateDirectory = "grafana-mcp";
      CacheDirectory = "grafana-mcp";
      Restart = "on-failure";
      RestartSec = 10;
      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
    };
  };
}
