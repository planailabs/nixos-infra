{ config, pkgs, lib, ... }:

with lib;

let
  # Home for the obsidian system user. The vault lives at $HOME/knowledge —
  # programs.obsidian (home-manager) materializes plugins/data.json relative
  # to that path.
  configHome = "/var/lib/obsidian/home";
  vaultName = "knowledge";
  vaultDir = "${configHome}/${vaultName}";
  vaultRepo = "https://git.plan.ai/plan-ai/knowledge.git";

  # Obsidian Local REST API plugin endpoint (HTTP, plaintext) on loopback.
  restApiPort = 27123;

  # obsidian-mcp-server HTTP transport listens here.
  mcpHost = "127.0.0.1";
  mcpPort = 3010;

  # Bootstrap script: clones / fast-forwards the vault. Plugin install +
  # data.json + community-plugins.json are owned by home-manager
  # (programs.obsidian) and applied on top of the cloned tree.
  vaultSetup = pkgs.writeShellApplication {
    name = "obsidian-vault-setup";
    runtimeInputs = with pkgs; [ git coreutils ];
    text = ''
      set -euo pipefail

      VAULT="${vaultDir}"

      if [ ! -d "$VAULT/.git" ]; then
        git clone "${vaultRepo}" "$VAULT"
      else
        git -C "$VAULT" fetch --quiet origin
        # Fast-forward only — preserve any uncommitted local edits.
        git -C "$VAULT" merge --ff-only --quiet FETCH_HEAD || true
      fi
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
    description = "Clone / fast-forward the plan-ai knowledge vault";
    wantedBy = [ "multi-user.target" ];
    # Ensure the vault tree exists before home-manager symlinks plugin
    # contents into it, and before Obsidian is launched against it.
    before = [ "home-manager-obsidian.service" "obsidian.service" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${vaultSetup}/bin/obsidian-vault-setup";
      User = "obsidian";
      Group = "obsidian";
    };
  };

  # Headless Obsidian — Electron under Xvfb so the Local REST API plugin can
  # serve requests from the bundled Express server inside the renderer.
  systemd.services.obsidian = {
    description = "Headless Obsidian (vault host for Local REST API)";
    wantedBy = [ "multi-user.target" ];
    after = [ "obsidian-vault-setup.service" "home-manager-obsidian.service" ];
    requires = [ "obsidian-vault-setup.service" "home-manager-obsidian.service" ];

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
      # Mark the registered vault as currently open. Without this Obsidian
      # falls into the vault picker, which never gets a click in headless
      # mode and freezes the renderer before plugins load.
      #
      # Then disable Restricted Mode by writing the
      # `enable-plugin-<appId>` key directly into Electron's localStorage
      # LevelDB. Otherwise Obsidian refuses to load community plugins
      # (incl. Local REST API) and `:27123` never binds.
      ExecStartPre = [
        "${pkgs.writeShellScript "obsidian-mark-vault-open" ''
          set -euo pipefail
          cfg="${configHome}/.config/obsidian/obsidian.json"
          if [ -f "$cfg" ]; then
            tmp="$(${pkgs.coreutils}/bin/mktemp)"
            ${pkgs.jq}/bin/jq '.vaults |= with_entries(.value.open = true)' "$cfg" > "$tmp"
            ${pkgs.coreutils}/bin/install -m 0644 "$tmp" "$cfg"
            rm -f "$tmp"
          fi
        ''}"
        "${pkgs.writers.writePython3 "obsidian-trust-plugins" {
          libraries = [ pkgs.python3Packages.plyvel ];
          flakeIgnore = [ "E501" "E401" ];
        } ''
          import json
          import os
          import sys
          import plyvel

          home = os.environ.get("HOME", "${configHome}")
          obsidian_json = os.path.join(home, ".config", "obsidian", "obsidian.json")
          db_path = os.path.join(home, ".config", "obsidian", "Local Storage", "leveldb")

          if not os.path.exists(obsidian_json):
              sys.exit(0)

          with open(obsidian_json) as fh:
              cfg = json.load(fh)

          # The renderer's `app.appId` is the per-vault id — the key under
          # .vaults in obsidian.json — not the global instance id at
          # ~/.config/obsidian/id. We seed enable-plugin-<appId>=true for
          # every registered vault so Restricted Mode is off on first open.
          vault_ids = list((cfg.get("vaults") or {}).keys())
          if not vault_ids:
              sys.exit(0)

          os.makedirs(db_path, exist_ok=True)

          # Chromium localStorage layout:
          #   key   = b"_<origin>\x00\x01<storage-key>"
          #   value = b"\x01" + utf-16-le bytes of the value
          origin = b"app://obsidian.md"
          db_val = b"\x01" + "true".encode("utf-16-le")

          db = plyvel.DB(db_path, create_if_missing=True)
          try:
              with db.write_batch(transaction=True) as wb:
                  for app_id in vault_ids:
                      storage_key = ("enable-plugin-" + app_id).encode("ascii")
                      wb.put(b"_" + origin + b"\x00\x01" + storage_key, db_val)
          finally:
              db.close()
        ''}"
      ];
      ExecStart = "${pkgs.xvfb-run}/bin/xvfb-run -a -s '-screen 0 1280x720x24' ${pkgs.obsidian}/bin/obsidian --no-sandbox --disable-gpu";
      Restart = "always";
      RestartSec = "10s";
      TimeoutStopSec = "10s";
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
      LOGS_DIR = "/var/log/obsidian-mcp-server";
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
      LogsDirectory = "obsidian-mcp-server";
      LogsDirectoryMode = "0750";
    };
  };
}
