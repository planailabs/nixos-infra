{ config, pkgs, lib, ... }:

with lib;

let
  vaultDir = "/var/lib/obsidian/vault";
  configHome = "/var/lib/obsidian/home";
  vaultRepo = "https://git.plan.ai/plan-ai/knowledge.git";

  # Obsidian Local REST API plugin endpoint (HTTP, plaintext) on loopback.
  restApiPort = 27123;

  # obsidian-mcp-server HTTP transport listens here.
  mcpHost = "127.0.0.1";
  mcpPort = 3010;

  # Bootstrap script: clones / fast-forwards the vault, links the Local REST
  # API plugin into .obsidian/plugins/, and writes its data.json from the
  # operator-supplied API key.
  vaultSetup = pkgs.writeShellApplication {
    name = "obsidian-vault-setup";
    runtimeInputs = with pkgs; [ git coreutils jq ];
    text = ''
      set -euo pipefail

      VAULT="${vaultDir}"
      HOME_DIR="${configHome}"
      PLUGIN_SRC="${pkgs.obsidian-local-rest-api-plugin}"
      API_KEY_FILE="''${OBSIDIAN_API_KEY_FILE:-/etc/obsidian/api-key}"

      if [ ! -f "$API_KEY_FILE" ]; then
        echo "missing api key file at $API_KEY_FILE" >&2
        exit 1
      fi
      API_KEY="$(tr -d '\n\r' < "$API_KEY_FILE")"

      mkdir -p "$HOME_DIR" "$(dirname "$VAULT")"

      if [ ! -d "$VAULT/.git" ]; then
        git clone "${vaultRepo}" "$VAULT"
      else
        git -C "$VAULT" fetch --quiet origin
        # Fast-forward only — preserve any uncommitted local edits.
        git -C "$VAULT" merge --ff-only --quiet FETCH_HEAD || true
      fi

      mkdir -p "$VAULT/.obsidian/plugins/obsidian-local-rest-api"
      cp -f "$PLUGIN_SRC/main.js"       "$VAULT/.obsidian/plugins/obsidian-local-rest-api/main.js"
      cp -f "$PLUGIN_SRC/manifest.json" "$VAULT/.obsidian/plugins/obsidian-local-rest-api/manifest.json"
      cp -f "$PLUGIN_SRC/styles.css"    "$VAULT/.obsidian/plugins/obsidian-local-rest-api/styles.css"

      jq -n \
        --arg apiKey "$API_KEY" \
        --argjson port ${toString restApiPort} \
        '{ apiKey: $apiKey, insecurePort: $port, enableInsecureServer: true, bindingHost: "127.0.0.1" }' \
        > "$VAULT/.obsidian/plugins/obsidian-local-rest-api/data.json"

      # community-plugins.json: ensure obsidian-local-rest-api is enabled.
      CP="$VAULT/.obsidian/community-plugins.json"
      if [ -f "$CP" ]; then
        tmp="$(mktemp)"
        jq '. + ["obsidian-local-rest-api"] | unique' "$CP" > "$tmp"
        mv "$tmp" "$CP"
      else
        echo '["obsidian-local-rest-api"]' > "$CP"
      fi

      chown -R obsidian:obsidian "$VAULT" "$HOME_DIR"
    '';
  };
in
{
  users.users.obsidian = {
    isSystemUser = true;
    group = "obsidian";
    home = configHome;
    createHome = false;
  };
  users.groups.obsidian = { };

  systemd.tmpfiles.rules = [
    "d /var/lib/obsidian            0750 obsidian obsidian -"
    "d ${configHome}                0750 obsidian obsidian -"
  ];

  systemd.services.obsidian-vault-setup = {
    description = "Clone the plan-ai vault and install the Local REST API plugin";
    wantedBy = [ "multi-user.target" ];
    before = [ "obsidian.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${vaultSetup}/bin/obsidian-vault-setup";
      User = "root";
    };
    environment = {
      OBSIDIAN_API_KEY_FILE = "/etc/obsidian/api-key";
    };
  };

  # Headless Obsidian — Electron under Xvfb so the Local REST API plugin can
  # serve requests from the bundled Express server inside the renderer.
  systemd.services.obsidian = {
    description = "Headless Obsidian (vault host for Local REST API)";
    wantedBy = [ "multi-user.target" ];
    after = [ "obsidian-vault-setup.service" "network-online.target" ];
    wants = [ "network-online.target" ];
    requires = [ "obsidian-vault-setup.service" ];

    path = with pkgs; [ obsidian xvfb dbus ];

    environment = {
      HOME = configHome;
      XDG_CONFIG_HOME = "${configHome}/.config";
      XDG_DATA_HOME = "${configHome}/.local/share";
      XDG_CACHE_HOME = "${configHome}/.cache";
      ELECTRON_DISABLE_SANDBOX = "1";
    };

    serviceConfig = {
      Type = "simple";
      User = "obsidian";
      Group = "obsidian";
      ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run -a -s '-screen 0 1280x720x24' ${pkgs.obsidian}/bin/obsidian --no-sandbox --disable-gpu ${vaultDir}";
      Restart = "always";
      RestartSec = "10s";
      # Loopback only — the plugin binds 127.0.0.1.
      PrivateTmp = true;
    };
  };

  systemd.services.obsidian-mcp-server = {
    description = "obsidian-mcp-server (HTTP transport, fronts the Obsidian Local REST API)";
    wantedBy = [ "multi-user.target" ];
    after = [ "obsidian.service" ];
    requires = [ "obsidian.service" ];

    environment = {
      MCP_TRANSPORT_TYPE = "http";
      MCP_HTTP_HOST = mcpHost;
      MCP_HTTP_PORT = toString mcpPort;
      MCP_HTTP_ENDPOINT_PATH = "/mcp";
      MCP_SESSION_MODE = "stateless";
      MCP_LOG_LEVEL = "info";
      MCP_FORCE_CONSOLE_LOGGING = "true";
      OBSIDIAN_BASE_URL = "http://127.0.0.1:${toString restApiPort}";
      OBSIDIAN_VERIFY_SSL = "false";
      OBSIDIAN_READ_ONLY = "true";
    };

    serviceConfig = {
      Type = "simple";
      User = "obsidian";
      Group = "obsidian";
      EnvironmentFile = "/etc/obsidian/mcp.env";
      ExecStart = "${pkgs.obsidian-mcp-server}/bin/obsidian-mcp-server";
      Restart = "always";
      RestartSec = "5s";
    };
  };
}
